#include <napi/native_api.h>

#include <atomic>
#include <chrono>
#include <cstdio>
#include <deque>
#include <memory>
#include <mutex>
#include <string>
#include <unordered_map>
#include <vector>
#include <zlib.h>

extern "C" {
#include "quickjs/quickjs.h"
}

namespace {
constexpr size_t QUICKJS_MEMORY_LIMIT = 64 * 1024 * 1024;
constexpr size_t QUICKJS_STACK_LIMIT = 1024 * 1024;
constexpr int64_t QUICKJS_LOAD_TIMEOUT_MS = 10000;
constexpr int64_t QUICKJS_DISPATCH_TIMEOUT_MS = 30000;
constexpr int QUICKJS_MAX_PENDING_JOB_STEPS = 100000;

struct BridgeEvent {
    std::string action;
    std::string payload_json;
};

enum class PumpResultType {
    Idle,
    Host,
    Done,
};

struct PumpResult {
    PumpResultType type = PumpResultType::Idle;
    std::string action;
    std::string payload_json;
};

static std::string JsonEscape(const std::string &value)
{
    std::string escaped;
    escaped.reserve(value.size() + 16);
    char buffer[7] = {0};
    for (char ch : value) {
        switch (ch) {
            case '\\':
                escaped += "\\\\";
                break;
            case '"':
                escaped += "\\\"";
                break;
            case '\b':
                escaped += "\\b";
                break;
            case '\f':
                escaped += "\\f";
                break;
            case '\n':
                escaped += "\\n";
                break;
            case '\r':
                escaped += "\\r";
                break;
            case '\t':
                escaped += "\\t";
                break;
            default:
                if (static_cast<unsigned char>(ch) < 0x20) {
                    std::snprintf(buffer, sizeof(buffer), "\\u%04x", ch & 0xff);
                    escaped += buffer;
                } else {
                    escaped.push_back(ch);
                }
                break;
        }
    }
    return escaped;
}

static std::string MakeStatusEnvelope(bool status, const std::string &payload_json, const std::string &error_message)
{
    if (status) {
        return std::string("{\"status\":true,\"payloadJson\":\"") + JsonEscape(payload_json) + "\"}";
    }
    return std::string("{\"status\":false,\"errorMessage\":\"") + JsonEscape(error_message) + "\"}";
}

static std::string MakeDispatchEnvelope(const PumpResult &result)
{
    switch (result.type) {
        case PumpResultType::Idle:
            return "{\"type\":\"idle\"}";
        case PumpResultType::Host:
            return std::string("{\"type\":\"host\",\"action\":\"") + JsonEscape(result.action) +
                "\",\"payloadJson\":\"" + JsonEscape(result.payload_json) + "\"}";
        case PumpResultType::Done:
            return std::string("{\"type\":\"done\",\"action\":\"") + JsonEscape(result.action) +
                "\",\"payloadJson\":\"" + JsonEscape(result.payload_json) + "\"}";
        default:
            return "{\"type\":\"error\",\"errorMessage\":\"unknown dispatch state\"}";
    }
}

static std::string MakeDispatchErrorEnvelope(const std::string &error_message)
{
    return std::string("{\"type\":\"error\",\"errorMessage\":\"") + JsonEscape(error_message) + "\"}";
}

static int64_t NowMs()
{
    auto now = std::chrono::steady_clock::now();
    return std::chrono::duration_cast<std::chrono::milliseconds>(now.time_since_epoch()).count();
}

static bool ReadStringArg(napi_env env, napi_value value, std::string &out)
{
    size_t length = 0;
    if (napi_get_value_string_utf8(env, value, nullptr, 0, &length) != napi_ok) {
        return false;
    }
    std::string buffer(length + 1, '\0');
    size_t copied = 0;
    if (napi_get_value_string_utf8(env, value, buffer.data(), buffer.size(), &copied) != napi_ok) {
        return false;
    }
    out.assign(buffer.c_str(), copied);
    return true;
}

static napi_value CreateUtf8(napi_env env, const std::string &value)
{
    napi_value result = nullptr;
    napi_create_string_utf8(env, value.c_str(), value.size(), &result);
    return result;
}

class QuickJsEngine {
public:
    QuickJsEngine() = default;

    ~QuickJsEngine()
    {
        Destroy();
    }

    bool LoadSource(const std::string &setup_script, std::string &payload_json, std::string &error_message)
    {
        if (!Reset(error_message)) {
            return false;
        }

        BeginTimedSection(QUICKJS_LOAD_TIMEOUT_MS);
        bool ok = Eval(setup_script, "<quickjs-source>", error_message);
        PumpResult result;
        if (ok) {
            ok = Pump(result, error_message);
        }
        EndTimedSection();

        if (!ok) {
            ClearQueues();
            return false;
        }
        payload_json = MakeDispatchEnvelope(result);
        return true;
    }

    bool Dispatch(const std::string &engine_key, const std::string &action,
        const std::string &data_json, std::string &dispatch_envelope, std::string &error_message)
    {
        if (!context_) {
            error_message = "QuickJS engine is not loaded";
            return false;
        }

        BeginTimedSection(QUICKJS_DISPATCH_TIMEOUT_MS);
        bool ok = InvokeNative(engine_key, action, data_json, error_message);
        PumpResult result;
        if (ok) {
            ok = Pump(result, error_message);
        }
        EndTimedSection();

        if (!ok) {
            ClearQueues();
            return false;
        }
        dispatch_envelope = MakeDispatchEnvelope(result);
        return true;
    }

private:
    static JSValue BridgeCall(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv)
    {
        (void)this_val;
        QuickJsEngine *engine = static_cast<QuickJsEngine *>(JS_GetContextOpaque(ctx));
        if (!engine) {
            return JS_ThrowInternalError(ctx, "QuickJS engine is not attached");
        }
        if (argc < 2) {
            return JS_ThrowTypeError(ctx, "__quickjs_bridge__ expects at least 2 arguments");
        }

        const char *action_cstr = JS_ToCString(ctx, argv[1]);
        if (!action_cstr) {
            return JS_EXCEPTION;
        }
        const char *payload_cstr = nullptr;
        if (argc >= 3) {
            payload_cstr = JS_ToCString(ctx, argv[2]);
            if (!payload_cstr) {
                JS_FreeCString(ctx, action_cstr);
                return JS_EXCEPTION;
            }
        }

        std::string action(action_cstr);
        std::string payload = payload_cstr ? payload_cstr : "null";
        JS_FreeCString(ctx, action_cstr);
        if (payload_cstr) {
            JS_FreeCString(ctx, payload_cstr);
        }

        if (action == "init" || action == "response") {
            engine->terminal_events_.push_back({ action, payload });
        } else {
            engine->host_events_.push_back({ action, payload });
        }
        return JS_UNDEFINED;
    }

    static JSValue BridgeSetTimeout(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv)
    {
        (void)this_val;
        QuickJsEngine *engine = static_cast<QuickJsEngine *>(JS_GetContextOpaque(ctx));
        if (!engine) {
            return JS_ThrowInternalError(ctx, "QuickJS engine is not attached");
        }
        if (argc < 3) {
            return JS_ThrowTypeError(ctx, "__quickjs_set_timeout__ expects 3 arguments");
        }

        int32_t id = 0;
        int32_t ms = 0;
        if (JS_ToInt32(ctx, &id, argv[1]) < 0 || JS_ToInt32(ctx, &ms, argv[2]) < 0) {
            return JS_EXCEPTION;
        }
        if (ms < 0) {
            ms = 0;
        }
        engine->host_events_.push_back({
            "__set_timeout__",
            std::string("{\"id\":") + std::to_string(id) + ",\"ms\":" + std::to_string(ms) + "}"
        });
        return JS_UNDEFINED;
    }

    static JSValue BridgeInflate(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv)
    {
        (void)this_val;
        if (argc < 1 || !JS_IsObject(argv[0])) {
            return JS_ThrowTypeError(ctx, "__quickjs_inflate__ expects an array of byte values");
        }

        // Read input array length
        JSValue lengthVal = JS_GetPropertyStr(ctx, argv[0], "length");
        int64_t inputLen = 0;
        if (JS_ToInt64(ctx, &inputLen, lengthVal) < 0 || inputLen <= 0) {
            JS_FreeValue(ctx, lengthVal);
            return JS_ThrowTypeError(ctx, "invalid inflate input length");
        }
        JS_FreeValue(ctx, lengthVal);
        if (inputLen > 16 * 1024 * 1024) {
            return JS_ThrowRangeError(ctx, "inflate input too large");
        }

        // Read input bytes from JS array
        std::vector<uint8_t> inputBuf(static_cast<size_t>(inputLen));
        for (int64_t i = 0; i < inputLen; i++) {
            JSValue elem = JS_GetPropertyUint32(ctx, argv[0], static_cast<uint32_t>(i));
            int32_t byteVal = 0;
            JS_ToInt32(ctx, &byteVal, elem);
            JS_FreeValue(ctx, elem);
            inputBuf[static_cast<size_t>(i)] = static_cast<uint8_t>(byteVal & 0xFF);
        }

        // Try raw inflate, then zlib header, then gzip
        int wbits_options[] = {-MAX_WBITS, MAX_WBITS, MAX_WBITS + 16};
        for (int wi = 0; wi < 3; wi++) {
            z_stream strm = {};
            strm.next_in = inputBuf.data();
            strm.avail_in = static_cast<uInt>(inputBuf.size());

            int ret = inflateInit2(&strm, wbits_options[wi]);
            if (ret != Z_OK) {
                continue;
            }

            std::vector<uint8_t> output;
            uint8_t chunk[16384];
            bool failed = false;
            do {
                strm.next_out = chunk;
                strm.avail_out = sizeof(chunk);
                ret = inflate(&strm, Z_NO_FLUSH);
                if (ret == Z_STREAM_ERROR || ret == Z_NEED_DICT || ret == Z_DATA_ERROR || ret == Z_MEM_ERROR) {
                    failed = true;
                    break;
                }
                size_t have = sizeof(chunk) - strm.avail_out;
                output.insert(output.end(), chunk, chunk + have);
                if (output.size() > 16u * 1024 * 1024) {
                    failed = true;
                    break;
                }
            } while (ret != Z_STREAM_END);
            inflateEnd(&strm);

            if (!failed && ret == Z_STREAM_END) {
                // Build JS array from output bytes
                JSValue result = JS_NewArray(ctx);
                for (size_t i = 0; i < output.size(); i++) {
                    JS_SetPropertyUint32(ctx, result, static_cast<uint32_t>(i), JS_NewInt32(ctx, output[i]));
                }
                return result;
            }
        }

        return JS_ThrowInternalError(ctx, "inflate decompression failed");
    }

    static int InterruptHandler(JSRuntime *rt, void *opaque)
    {
        (void)rt;
        QuickJsEngine *engine = static_cast<QuickJsEngine *>(opaque);
        if (!engine || engine->interrupt_deadline_ms_ <= 0) {
            return 0;
        }
        return NowMs() > engine->interrupt_deadline_ms_ ? 1 : 0;
    }

    bool Reset(std::string &error_message)
    {
        Destroy();

        runtime_ = JS_NewRuntime();
        if (!runtime_) {
            error_message = "JS_NewRuntime failed";
            return false;
        }
        JS_SetMemoryLimit(runtime_, QUICKJS_MEMORY_LIMIT);
        JS_SetGCThreshold(runtime_, QUICKJS_MEMORY_LIMIT / 2);
        JS_SetMaxStackSize(runtime_, QUICKJS_STACK_LIMIT);
        JS_SetRuntimeOpaque(runtime_, this);
        JS_SetInterruptHandler(runtime_, InterruptHandler, this);

        context_ = JS_NewContext(runtime_);
        if (!context_) {
            error_message = "JS_NewContext failed";
            Destroy();
            return false;
        }
        JS_SetContextOpaque(context_, this);
        ClearQueues();

        JSValue global = JS_GetGlobalObject(context_);
        JSValue bridge = JS_NewCFunction(context_, BridgeCall, "__quickjs_bridge__", 3);
        if (JS_SetPropertyStr(context_, global, "__quickjs_bridge__", bridge) < 0) {
            JS_FreeValue(context_, global);
            error_message = "failed to expose __quickjs_bridge__";
            Destroy();
            return false;
        }
        JSValue timer = JS_NewCFunction(context_, BridgeSetTimeout, "__quickjs_set_timeout__", 3);
        if (JS_SetPropertyStr(context_, global, "__quickjs_set_timeout__", timer) < 0) {
            JS_FreeValue(context_, global);
            error_message = "failed to expose __quickjs_set_timeout__";
            Destroy();
            return false;
        }
        JSValue inflateFunc = JS_NewCFunction(context_, BridgeInflate, "__quickjs_inflate__", 1);
        if (JS_SetPropertyStr(context_, global, "__quickjs_inflate__", inflateFunc) < 0) {
            JS_FreeValue(context_, global);
            error_message = "failed to expose __quickjs_inflate__";
            Destroy();
            return false;
        }
        JS_FreeValue(context_, global);
        return true;
    }

    void Destroy()
    {
        ClearQueues();
        if (context_) {
            JS_FreeContext(context_);
            context_ = nullptr;
        }
        if (runtime_) {
            JS_FreeRuntime(runtime_);
            runtime_ = nullptr;
        }
        interrupt_deadline_ms_ = 0;
    }

    void ClearQueues()
    {
        host_events_.clear();
        terminal_events_.clear();
    }

    void BeginTimedSection(int64_t timeout_ms)
    {
        interrupt_deadline_ms_ = NowMs() + timeout_ms;
    }

    void EndTimedSection()
    {
        interrupt_deadline_ms_ = 0;
    }

    bool Eval(const std::string &script, const char *filename, std::string &error_message)
    {
        JSValue eval_result = JS_Eval(context_, script.c_str(), script.size(), filename, JS_EVAL_TYPE_GLOBAL);
        if (JS_IsException(eval_result)) {
            error_message = GetExceptionString(context_);
            return false;
        }
        JS_FreeValue(context_, eval_result);
        return true;
    }

    bool InvokeNative(const std::string &engine_key, const std::string &action,
        const std::string &data_json, std::string &error_message)
    {
        JSValue global = JS_GetGlobalObject(context_);
        JSValue func = JS_GetPropertyStr(context_, global, "__lx_native__");
        if (JS_IsException(func)) {
            JS_FreeValue(context_, global);
            error_message = GetExceptionString(context_);
            return false;
        }
        if (!JS_IsFunction(context_, func)) {
            JS_FreeValue(context_, func);
            JS_FreeValue(context_, global);
            error_message = "__lx_native__ is not ready";
            return false;
        }

        JSValue argv[3] = {
            JS_NewString(context_, engine_key.c_str()),
            JS_NewString(context_, action.c_str()),
            JS_NewString(context_, data_json.c_str())
        };
        JSValue call_result = JS_Call(context_, func, global, 3, argv);
        for (JSValue &value : argv) {
            JS_FreeValue(context_, value);
        }
        JS_FreeValue(context_, func);
        JS_FreeValue(context_, global);

        if (JS_IsException(call_result)) {
            error_message = GetExceptionString(context_);
            return false;
        }
        JS_FreeValue(context_, call_result);
        return true;
    }

    bool Pump(PumpResult &result, std::string &error_message)
    {
        for (int i = 0; i < QUICKJS_MAX_PENDING_JOB_STEPS; i++) {
            if (!terminal_events_.empty()) {
                result.type = PumpResultType::Done;
                result.action = terminal_events_.front().action;
                result.payload_json = terminal_events_.front().payload_json;
                terminal_events_.pop_front();
                return true;
            }
            if (!host_events_.empty()) {
                result.type = PumpResultType::Host;
                result.action = host_events_.front().action;
                result.payload_json = host_events_.front().payload_json;
                host_events_.pop_front();
                return true;
            }
            JSContext *pending_ctx = nullptr;
            int exec_result = JS_ExecutePendingJob(runtime_, &pending_ctx);
            if (exec_result > 0) {
                continue;
            }
            if (exec_result == 0) {
                result.type = PumpResultType::Idle;
                result.action.clear();
                result.payload_json.clear();
                return true;
            }
            error_message = GetExceptionString(pending_ctx ? pending_ctx : context_);
            return false;
        }
        error_message = "QuickJS pending job limit exceeded";
        return false;
    }

    static std::string GetExceptionString(JSContext *ctx)
    {
        if (!ctx) {
            return "QuickJS unknown exception";
        }
        JSValue exception = JS_GetException(ctx);
        std::string message = ToStdString(ctx, exception);
        JSValue stack = JS_GetPropertyStr(ctx, exception, "stack");
        if (!JS_IsUndefined(stack)) {
            std::string stack_message = ToStdString(ctx, stack);
            if (!stack_message.empty()) {
                message = stack_message;
            }
        }
        JS_FreeValue(ctx, stack);
        JS_FreeValue(ctx, exception);
        if (message.empty()) {
            return "QuickJS exception";
        }
        return message;
    }

    static std::string ToStdString(JSContext *ctx, JSValueConst value)
    {
        const char *cstr = JS_ToCString(ctx, value);
        if (!cstr) {
            return "";
        }
        std::string out(cstr);
        JS_FreeCString(ctx, cstr);
        return out;
    }

    JSRuntime *runtime_ = nullptr;
    JSContext *context_ = nullptr;
    std::deque<BridgeEvent> host_events_;
    std::deque<BridgeEvent> terminal_events_;
    int64_t interrupt_deadline_ms_ = 0;
};

static std::mutex g_engine_mutex;
static std::unordered_map<std::string, std::shared_ptr<QuickJsEngine>> g_engines;
static std::atomic<uint64_t> g_engine_counter { 1 };

static std::shared_ptr<QuickJsEngine> GetEngine(const std::string &engine_id)
{
    std::lock_guard<std::mutex> lock(g_engine_mutex);
    auto it = g_engines.find(engine_id);
    if (it == g_engines.end()) {
        return nullptr;
    }
    return it->second;
}

static napi_value CreateEngine(napi_env env, napi_callback_info info)
{
    (void)info;
    std::string engine_id = "engine_" + std::to_string(g_engine_counter.fetch_add(1));
    {
        std::lock_guard<std::mutex> lock(g_engine_mutex);
        g_engines[engine_id] = std::make_shared<QuickJsEngine>();
    }
    return CreateUtf8(env, engine_id);
}

static napi_value DestroyEngine(napi_env env, napi_callback_info info)
{
    size_t argc = 1;
    napi_value argv[1] = { nullptr };
    napi_get_cb_info(env, info, &argc, argv, nullptr, nullptr);
    if (argc >= 1) {
        std::string engine_id;
        if (ReadStringArg(env, argv[0], engine_id)) {
            std::lock_guard<std::mutex> lock(g_engine_mutex);
            g_engines.erase(engine_id);
        }
    }
    napi_value result = nullptr;
    napi_get_undefined(env, &result);
    return result;
}

static napi_value LoadSource(napi_env env, napi_callback_info info)
{
    size_t argc = 2;
    napi_value argv[2] = { nullptr };
    napi_get_cb_info(env, info, &argc, argv, nullptr, nullptr);
    if (argc < 2) {
        return CreateUtf8(env, MakeStatusEnvelope(false, "", "loadSource expects 2 string arguments"));
    }

    std::string engine_id;
    std::string setup_script;
    if (!ReadStringArg(env, argv[0], engine_id) || !ReadStringArg(env, argv[1], setup_script)) {
        return CreateUtf8(env, MakeStatusEnvelope(false, "", "invalid loadSource arguments"));
    }

    std::shared_ptr<QuickJsEngine> engine = GetEngine(engine_id);
    if (!engine) {
        return CreateUtf8(env, MakeStatusEnvelope(false, "", "QuickJS engine not found"));
    }

    std::string payload_json;
    std::string error_message;
    if (!engine->LoadSource(setup_script, payload_json, error_message)) {
        return CreateUtf8(env, MakeStatusEnvelope(false, "", error_message));
    }
    return CreateUtf8(env, MakeStatusEnvelope(true, payload_json, ""));
}

static napi_value Dispatch(napi_env env, napi_callback_info info)
{
    size_t argc = 4;
    napi_value argv[4] = { nullptr };
    napi_get_cb_info(env, info, &argc, argv, nullptr, nullptr);
    if (argc < 4) {
        return CreateUtf8(env, MakeDispatchErrorEnvelope("dispatch expects 4 string arguments"));
    }

    std::string engine_id;
    std::string engine_key;
    std::string action;
    std::string data_json;
    if (!ReadStringArg(env, argv[0], engine_id) ||
        !ReadStringArg(env, argv[1], engine_key) ||
        !ReadStringArg(env, argv[2], action) ||
        !ReadStringArg(env, argv[3], data_json)) {
        return CreateUtf8(env, MakeDispatchErrorEnvelope("invalid dispatch arguments"));
    }

    std::shared_ptr<QuickJsEngine> engine = GetEngine(engine_id);
    if (!engine) {
        return CreateUtf8(env, MakeDispatchErrorEnvelope("QuickJS engine not found"));
    }

    std::string envelope_json;
    std::string error_message;
    if (!engine->Dispatch(engine_key, action, data_json, envelope_json, error_message)) {
        return CreateUtf8(env, MakeDispatchErrorEnvelope(error_message));
    }
    return CreateUtf8(env, envelope_json);
}

static napi_value RawInflate(napi_env env, napi_callback_info info)
{
    size_t argc = 1;
    napi_value argv[1] = {nullptr};
    napi_get_cb_info(env, info, &argc, argv, nullptr, nullptr);
    if (argc < 1) {
        napi_throw_error(env, nullptr, "rawInflate expects 1 ArrayBuffer argument");
        return nullptr;
    }

    bool is_arraybuffer = false;
    napi_is_arraybuffer(env, argv[0], &is_arraybuffer);
    if (!is_arraybuffer) {
        napi_throw_error(env, nullptr, "rawInflate expects ArrayBuffer");
        return nullptr;
    }

    void *input_data = nullptr;
    size_t input_length = 0;
    napi_get_arraybuffer_info(env, argv[0], &input_data, &input_length);
    if (!input_data || input_length == 0) {
        napi_throw_error(env, nullptr, "empty inflate input");
        return nullptr;
    }

    // Try raw inflate (-MAX_WBITS), then zlib header (MAX_WBITS), then gzip (MAX_WBITS+16)
    int wbits_options[] = {-MAX_WBITS, MAX_WBITS, MAX_WBITS + 16};
    for (int wi = 0; wi < 3; wi++) {
        z_stream strm = {};
        strm.next_in = static_cast<Bytef *>(input_data);
        strm.avail_in = static_cast<uInt>(input_length);

        int ret = inflateInit2(&strm, wbits_options[wi]);
        if (ret != Z_OK) {
            continue;
        }

        std::vector<uint8_t> output;
        uint8_t chunk[16384];
        bool failed = false;
        do {
            strm.next_out = chunk;
            strm.avail_out = sizeof(chunk);
            ret = inflate(&strm, Z_NO_FLUSH);
            if (ret == Z_STREAM_ERROR || ret == Z_NEED_DICT || ret == Z_DATA_ERROR || ret == Z_MEM_ERROR) {
                failed = true;
                break;
            }
            size_t have = sizeof(chunk) - strm.avail_out;
            output.insert(output.end(), chunk, chunk + have);
            if (output.size() > 16u * 1024 * 1024) {
                failed = true;
                break;
            }
        } while (ret != Z_STREAM_END);
        inflateEnd(&strm);

        if (!failed && ret == Z_STREAM_END) {
            void *result_data = nullptr;
            napi_value result_buffer = nullptr;
            napi_create_arraybuffer(env, output.size(), &result_data, &result_buffer);
            if (result_data && !output.empty()) {
                memcpy(result_data, output.data(), output.size());
            }
            return result_buffer;
        }
    }

    napi_throw_error(env, nullptr, "inflate decompression failed");
    return nullptr;
}
} // namespace

EXTERN_C_START
static napi_value Init(napi_env env, napi_value exports)
{
    napi_property_descriptor desc[] = {
        { "createEngine", nullptr, CreateEngine, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "destroyEngine", nullptr, DestroyEngine, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "loadSource", nullptr, LoadSource, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "dispatch", nullptr, Dispatch, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "rawInflate", nullptr, RawInflate, nullptr, nullptr, nullptr, napi_default, nullptr },
    };
    napi_define_properties(env, exports, sizeof(desc) / sizeof(desc[0]), desc);
    return exports;
}
EXTERN_C_END

static napi_module entryModule = {
    .nm_version = 1,
    .nm_flags = 0,
    .nm_filename = nullptr,
    .nm_register_func = Init,
    .nm_modname = "entry",
    .nm_priv = nullptr,
    .reserved = { 0 },
};

extern "C" __attribute__((constructor)) void RegisterEntryModule(void)
{
    napi_module_register(&entryModule);
}
