/**
 * Node.js 兼容性测试：验证自定义音源脚本能否在 LxUserApiPreload 协议下正确解析和执行。
 *
 * 注意：这不是原生 QuickJS / libentry.so 集成测试。
 * 当前脚本会模拟 QuickJS 的桥接函数 (__quickjs_bridge__, __quickjs_set_timeout__)，
 * 并使用 Node.js vm 模块在沙箱中运行预加载脚本 + 用户脚本。
 *
 * 异步流程：
 *   脚本加载 → lx.request(HTTP) → bridge('request')
 *   → 宿主执行 HTTP → __lx_native__('response', httpResp)
 *   → promise 链继续 → send('inited') → bridge('init')
 *
 * 用法: node entry/src/test/test-custom-source.mjs [脚本路径] [--verify-url]
 * 默认使用仓库内置 fixture: entry/src/test/fixtures/minimal-custom-source.js
 */

import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';
import http from 'node:http';
import https from 'node:https';
import { URL } from 'node:url';
import { fileURLToPath } from 'node:url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// ─── 配置 ───────────────────────────────────────────
const cliArgs = process.argv.slice(2);
const VERIFY_URL_FLAG = '--verify-url';
const verifyUrl = cliArgs.includes(VERIFY_URL_FLAG);
const inputScriptPath = cliArgs.find((arg) => arg !== VERIFY_URL_FLAG) || '';
const DEFAULT_SCRIPT_PATH = path.resolve(__dirname, './fixtures/minimal-custom-source.js');
const scriptPath = inputScriptPath
  ? (path.isAbsolute(inputScriptPath) ? inputScriptPath : path.resolve(process.cwd(), inputScriptPath))
  : DEFAULT_SCRIPT_PATH;

// ─── 颜色 ───────────────────────────────────────────
const GREEN = '\x1b[32m';
const RED = '\x1b[31m';
const YELLOW = '\x1b[33m';
const CYAN = '\x1b[36m';
const RESET = '\x1b[0m';
const BOLD = '\x1b[1m';

function logPass(msg) { console.log(`  ${GREEN}✓${RESET} ${msg}`); }
function logFail(msg) { console.log(`  ${RED}✗${RESET} ${msg}`); }
function logInfo(msg) { console.log(`  ${CYAN}ℹ${RESET} ${msg}`); }
function logSection(msg) { console.log(`\n${BOLD}${msg}${RESET}`); }

let passed = 0;
let failed = 0;

function fail(msg) {
  failed++;
  logFail(msg);
}

function assert(condition, msg) {
  if (condition) { passed++; logPass(msg); }
  else { failed++; logFail(msg); }
  return condition;
}

function printSummary() {
  logSection('=== 测试总结 ===');
  console.log(`  总计: ${passed + failed}, ${GREEN}通过: ${passed}${RESET}, ${failed > 0 ? RED : GREEN}失败: ${failed}${RESET}`);
  if (failed > 0) process.exit(1);
}

// ─── HTTP 请求工具 ───────────────────────────────────
function executeHttpRequest(urlStr, options = {}) {
  return new Promise((resolve, reject) => {
    if (!urlStr) { reject(new Error('no url')); return; }
    const urlObj = new URL(urlStr);
    const lib = urlObj.protocol === 'https:' ? https : http;
    const headers = options.headers || {};
    if (!headers['User-Agent']) {
      headers['User-Agent'] = 'Mozilla/5.0 (Linux; HarmonyOS 5.0) AppleWebKit/537.36';
    }
    const reqOpts = { method: (options.method || 'GET').toUpperCase(), headers, timeout: 15000 };
    let postData = null;
    if (options.body) {
      postData = typeof options.body === 'string' ? options.body : JSON.stringify(options.body);
    } else if (options.form) {
      postData = new URLSearchParams(options.form).toString();
      if (!headers['Content-Type']) headers['Content-Type'] = 'application/x-www-form-urlencoded';
    }
    const req = lib.request(urlObj, reqOpts, (res) => {
      const chunks = [];
      res.on('data', c => chunks.push(c));
      res.on('end', () => {
        const raw = Buffer.concat(chunks).toString('utf-8');
        let body = raw;
        try { body = JSON.parse(raw); } catch (_) {}
        resolve({ statusCode: res.statusCode, statusMessage: res.statusMessage, headers: res.headers, body, raw });
      });
    });
    req.on('error', reject);
    req.on('timeout', () => { req.destroy(); reject(new Error('HTTP timeout')); });
    if (postData) req.write(postData);
    req.end();
  });
}

// ─── 延迟 / microtask 工具 ───────────────────────────
function tick(ms = 50) { return new Promise(r => setTimeout(r, ms)); }

// ─── 1. 读取文件 ─────────────────────────────────────
logSection('=== 测试自定义音源脚本 ===');
logInfo('说明: 当前脚本使用 Node.js vm 模拟 QuickJS 桥接，验证的是预加载协议兼容性，不是 libentry.so 原生 QuickJS。');
logInfo(`脚本路径: ${scriptPath}`);
logInfo(`URL 连通性校验: ${verifyUrl ? '开启' : '关闭（使用 --verify-url 可开启）'}`);

let userScript;
try {
  userScript = fs.readFileSync(scriptPath, 'utf-8');
  logPass(`脚本文件读取成功 (${userScript.length} 字节)`);
} catch (e) {
  fail(`无法读取脚本文件: ${e.message}`);
  process.exit(1);
}

// ─── 2. JSDoc 元数据解析测试 ──────────────────────────
logSection('测试 1: JSDoc 元数据解析');

function parseLxSourceScriptInfo(script) {
  const limits = { name: 24, description: 36, author: 56, homepage: 1024, version: 36 };
  const infos = { name: '', description: '', author: '', homepage: '', version: '' };
  const m = /^\/\*[\S|\s]+?\*\//.exec(script);
  if (!m) return infos;
  for (const line of m[0].split(/\r?\n/)) {
    const lm = /^\s?\*\s?@(\w+)\s(.+)$/.exec(line);
    if (!lm || limits[lm[1]] == null) continue;
    let v = lm[2].trim();
    if (v.length > limits[lm[1]]) v = v.substring(0, limits[lm[1]]) + '...';
    infos[lm[1]] = v;
  }
  return infos;
}

const metadata = parseLxSourceScriptInfo(userScript);
assert(metadata.name.length > 0, `@name 解析成功: "${metadata.name}"`);
assert(metadata.version.length > 0, `@version 解析成功: "${metadata.version}"`);
assert(metadata.description.length > 0, `@description 解析成功: "${metadata.description}"`);
logInfo(`@author: "${metadata.author}"`);
logInfo(`@homepage: "${metadata.homepage}"`);

// ─── 3. 读取预加载脚本 ────────────────────────────────
logSection('测试 2: 预加载脚本加载');

const preloadEtsPath = path.resolve(__dirname, '../main/ets/utils/LxUserApiPreload.ets');
let preloadEtsContent;
try {
  preloadEtsContent = fs.readFileSync(preloadEtsPath, 'utf-8');
  logPass(`预加载文件读取成功 (${preloadEtsContent.length} 字节)`);
} catch (e) {
  fail(`无法读取预加载文件: ${e.message}`);
  process.exit(1);
}

const rawStart = preloadEtsContent.indexOf('String.raw`');
const rawEnd = preloadEtsContent.lastIndexOf('`;');
if (rawStart < 0 || rawEnd < 0) {
  fail('无法从 LxUserApiPreload.ets 中提取 JS 字符串');
  process.exit(1);
}
const preloadScript = preloadEtsContent.substring(rawStart + 'String.raw`'.length, rawEnd);
logPass(`预加载脚本提取成功 (${preloadScript.length} 字符)`);

// ─── 4. 引擎工厂 ────────────────────────────────────
/**
 * 创建 vm 沙箱引擎，自动处理 HTTP 请求 (bridge 'request' → executeHttpRequest → __lx_native__ 'response')
 */
function createEngine(preload, script, engineKey, scriptInfo) {
  const bridgeEvents = [];     // 所有 bridge 事件
  const pendingHttp = [];       // 待处理的 HTTP 请求
  let lxNativeFn = null;        // __lx_native__ 引用

  const sandbox = {
    globalThis: {},
    console: {
      log: () => {},
      info: () => {},
      warn: (...a) => console.warn('  [script warn]', ...a),
      error: (...a) => console.error('  [script error]', ...a),
    },
    __quickjs_bridge__: (key, action, payload) => {
      const ev = { key, action, payload: payload ? JSON.parse(payload) : null };
      bridgeEvents.push(ev);
      // 如果是 HTTP 请求，加到待处理队列
      if (action === 'request' && ev.payload?.requestKey && ev.payload?.url) {
        pendingHttp.push(ev.payload);
      }
    },
    __quickjs_set_timeout__: (key, id, ms) => {
      // 在 vm context 中回调 timer（我们直接调度到 Node.js setTimeout）
      setTimeout(() => {
        try {
          if (lxNativeFn) lxNativeFn(key, '__set_timeout__', JSON.stringify(id));
        } catch (_) {}
      }, Math.max(ms, 1));
    },
    Math, JSON, Object, Array, String, Number, Boolean, RegExp, Date, Error,
    TypeError, RangeError, SyntaxError, URIError, ReferenceError, EvalError,
    parseInt, parseFloat, isNaN, isFinite, NaN, Infinity, undefined,
    encodeURIComponent, decodeURIComponent, encodeURI, decodeURI,
    Uint8Array, Int8Array, Uint16Array, Int16Array, Uint32Array, Int32Array,
    Float32Array, Float64Array, ArrayBuffer, DataView,
    Map, Set, WeakMap, WeakSet, Promise, Symbol, Proxy, Reflect,
  };
  sandbox.globalThis = sandbox;
  sandbox.self = sandbox;
  sandbox.window = sandbox;

  const context = vm.createContext(sandbox);

  // 执行预加载脚本 — 它会定义 lx_setup 和 setTimeout/clearTimeout
  vm.runInContext(preload, context, { filename: 'preload.js' });

  // 调用 lx_setup（会定义 __lx_native__）
  const infoStr = JSON.stringify(scriptInfo).replace(/\\/g, '\\\\').replace(/'/g, "\\'");
  vm.runInContext(`lx_setup('${engineKey}', JSON.parse('${infoStr}'));`, context, { filename: 'setup.js' });

  // 获取 __lx_native__ 的引用
  lxNativeFn = vm.runInContext(`globalThis.__lx_native__`, context);

  // 执行用户脚本
  vm.runInContext(script, context, { filename: 'user-source.js' });

  return {
    bridgeEvents,
    pendingHttp,
    lxNative: lxNativeFn,
    context,
    /** 获取指定 action 的所有事件 */
    eventsOf(action) { return bridgeEvents.filter(e => e.action === action); },
    /** 获取最后一个指定 action 的事件 */
    lastEventOf(action) {
      for (let i = bridgeEvents.length - 1; i >= 0; i--) {
        if (bridgeEvents[i].action === action) return bridgeEvents[i];
      }
      return null;
    },
  };
}

// ─── 5. 执行初始化测试 ──────────────────────────────
logSection('测试 3: 脚本初始化 (lx.send inited)');

const ENGINE_KEY = `test_key_${Date.now()}`;
const scriptInfo = {
  name: metadata.name || 'test',
  description: metadata.description || '',
  version: metadata.version || '1.0.0',
  author: metadata.author || '',
  homepage: metadata.homepage || '',
};

let engine;
try {
  engine = createEngine(preloadScript, userScript, ENGINE_KEY, scriptInfo);
  logPass('脚本加载执行成功（无异常）');
} catch (e) {
  fail(`脚本执行失败: ${e.message}`);
  console.error(e.stack);
  printSummary();
  process.exit(1);
}

// 脚本加载后，checkUpdate() 发出了版本检查 HTTP 请求，init 事件还没有触发
let initEvent = engine.lastEventOf('init');
if (initEvent) {
  logPass('init 事件已同步触发（无需等待 HTTP）');
} else {
  logInfo(`init 事件未同步触发，检查是否有待处理的 HTTP 请求...`);

  if (engine.pendingHttp.length > 0) {
    logInfo(`有 ${engine.pendingHttp.length} 个待处理 HTTP 请求`);

    // 处理所有待处理的 HTTP 请求
    for (const httpReq of engine.pendingHttp) {
      logInfo(`  执行 HTTP: ${httpReq.options?.method || 'GET'} ${httpReq.url?.substring(0, 80)}`);
      try {
        const resp = await executeHttpRequest(httpReq.url, httpReq.options || {});
        logPass(`  HTTP 响应: ${resp.statusCode}`);

        // 将 HTTP 响应通过 __lx_native__ 送回脚本
        const responsePayload = {
          requestKey: httpReq.requestKey,
          error: resp.statusCode >= 200 && resp.statusCode < 400 ? null : `HTTP ${resp.statusCode}`,
          response: {
            statusCode: resp.statusCode,
            headers: resp.headers,
            body: resp.body,
          },
        };
        engine.lxNative(ENGINE_KEY, 'response', JSON.stringify(responsePayload));
      } catch (e) {
        logInfo(`  HTTP 请求失败: ${e.message}，发送错误响应`);
        // 即使 HTTP 失败，也要回送错误，这样 .catch() 会执行，init 仍然会触发
        engine.lxNative(ENGINE_KEY, 'response', JSON.stringify({
          requestKey: httpReq.requestKey,
          error: e.message,
          response: null,
        }));
      }
    }

    // 等待 microtask 队列 drain（.then/.catch 回调）
    await tick(200);

    initEvent = engine.lastEventOf('init');
  }
}

if (!assert(!!initEvent, 'init 事件已触发')) {
  logInfo(`所有 bridge 事件: [${engine.bridgeEvents.map(e => e.action).join(', ')}]`);
  // 打印详细信息辅助调试
  for (const ev of engine.bridgeEvents) {
    logInfo(`  ${ev.action}: ${JSON.stringify(ev.payload).substring(0, 200)}`);
  }
  printSummary();
  process.exit(1);
}

assert(initEvent.payload.status === true, `init status = true`);

const sources = initEvent.payload?.info?.sources || {};
const sourceKeys = Object.keys(sources);
assert(sourceKeys.length > 0, `init 返回了 ${sourceKeys.length} 个源: [${sourceKeys.join(', ')}]`);

for (const [src, info] of Object.entries(sources)) {
  logInfo(`  源 ${src}: type=${info.type}, actions=[${info.actions}], qualitys=[${info.qualitys}]`);
}

// ─── 6. 测试 musicUrl 请求 ────────────────────────────
logSection('测试 4: musicUrl 请求');

/**
 * 完整的 musicUrl 请求流程：
 * 1. __lx_native__(key, 'request', {requestKey, data:{source, action:'musicUrl', info}})
 * 2. 脚本的 on('request') handler 处理，可能直接 resolve(url) 或发 HTTP
 * 3. 如果发 HTTP → 我们执行 HTTP → __lx_native__('response', httpResp) → 脚本处理
 * 4. 最终 bridge('response', {requestKey, status, result:{data:{url}}})
 */
async function testMusicUrl(eng, source, quality) {
  logInfo(`请求 source=${source}, quality=${quality}...`);

  const requestKey = `musicUrl_test_${Date.now()}_${Math.random().toString(36).slice(2)}`;

  // 记住当前事件数量，之后只看新事件
  const startIdx = eng.bridgeEvents.length;
  const httpStart = eng.pendingHttp.length;

  // 派发 musicUrl 请求
  const requestData = {
    requestKey,
    data: {
      source,
      action: 'musicUrl',
      info: {
        type: quality,
        musicInfo: {
          name: '测试歌曲',
          singer: '测试歌手',
          source,
          songmid: '12345678',
          interval: '04:30',
          albumName: '测试专辑',
          albumId: 'album_1',
          img: '',
          hash: 'abc123def456',
          types: [{ type: quality, size: '' }],
          _types: { [quality]: { size: '' } },
          typeUrl: {},
          copyrightId: '',
        },
      },
    },
  };

  try {
    eng.lxNative(ENGINE_KEY, 'request', JSON.stringify(requestData));
  } catch (e) {
    fail(`dispatch request 失败: ${e.message}`);
    return null;
  }

  // 等待微任务
  await tick(100);

  // 查看是否有新的 HTTP 请求需要处理
  const newHttpReqs = eng.pendingHttp.slice(httpStart);
  if (newHttpReqs.length > 0) {
    logInfo(`需要执行 ${newHttpReqs.length} 个 HTTP 请求`);
    for (const httpReq of newHttpReqs) {
      logInfo(`  HTTP ${httpReq.options?.method || 'GET'} ${httpReq.url?.substring(0, 100)}`);
      try {
        const resp = await executeHttpRequest(httpReq.url, httpReq.options || {});
        logPass(`  HTTP 响应: ${resp.statusCode}`);
        eng.lxNative(ENGINE_KEY, 'response', JSON.stringify({
          requestKey: httpReq.requestKey,
          error: resp.statusCode >= 200 && resp.statusCode < 400 ? null : `HTTP ${resp.statusCode}`,
          response: { statusCode: resp.statusCode, headers: resp.headers, body: resp.body },
        }));
        await tick(100);
      } catch (e) {
        fail(`  HTTP 请求失败: ${e.message}`);
        eng.lxNative(ENGINE_KEY, 'response', JSON.stringify({
          requestKey: httpReq.requestKey, error: e.message, response: null,
        }));
        await tick(100);
      }
    }
  }

  // 查找 response 事件（只看新事件）
  const newEvents = eng.bridgeEvents.slice(startIdx);
  const responseEvent = newEvents.find(e => e.action === 'response' && e.payload?.requestKey === requestKey);

  if (!responseEvent) {
    fail(`未收到 musicUrl 响应`);
    logInfo(`新事件: [${newEvents.map(e => e.action).join(', ')}]`);
    return null;
  }

  if (responseEvent.payload.status) {
    const url = responseEvent.payload.result?.data?.url;
    logPass(`获得音乐 URL: ${url?.substring(0, 150)}`);
    assert(typeof url === 'string' && url.length > 0, 'URL 非空');
    assert(/^https?:/.test(url), 'URL 以 http(s) 开头');
    return url;
  } else {
    fail(`脚本返回错误: ${responseEvent.payload.errorMessage || 'unknown'}`);
    return null;
  }
}

// 对每个源测试第一个 quality
for (const source of sourceKeys) {
  const qualitys = sources[source]?.qualitys || [];
  if (qualitys.length === 0) continue;
  const quality = qualitys[0];
  const url = await testMusicUrl(engine, source, quality);

  if (typeof url === 'string' && /^https?:/.test(url) && verifyUrl) {
    // ─── 5a. 验证 URL 可访问 ───
    logSection(`测试 5: 验证 ${source}/${quality} URL 可访问`);
    try {
      const headResp = await executeHttpRequest(url, { method: 'HEAD' });
      if (headResp.statusCode >= 200 && headResp.statusCode < 400) {
        logPass(`URL 可访问: HTTP ${headResp.statusCode}`);
        if (headResp.headers['content-type']) {
          logInfo(`Content-Type: ${headResp.headers['content-type']}`);
        }
        if (headResp.headers['content-length']) {
          const sizeMB = (parseInt(headResp.headers['content-length']) / 1024 / 1024).toFixed(2);
          logInfo(`Content-Length: ${sizeMB} MB`);
        }
      } else {
        fail(`URL 返回 HTTP ${headResp.statusCode}`);
      }
    } catch (e) {
      logInfo(`URL HEAD 请求失败: ${e.message}（可能不支持 HEAD，尝试 GET 下载前 1KB）`);
      // 有些 CDN 不支持 HEAD，尝试 Range GET
      try {
        const getResp = await executeHttpRequest(url, {
          method: 'GET',
          headers: { 'Range': 'bytes=0-1023' },
        });
        if (getResp.statusCode >= 200 && getResp.statusCode < 400) {
          logPass(`GET Range 成功: HTTP ${getResp.statusCode}`);
          if (getResp.headers['content-type']) {
            logInfo(`Content-Type: ${getResp.headers['content-type']}`);
          }
        } else {
          fail(`GET Range 返回 HTTP ${getResp.statusCode}`);
        }
      } catch (e2) {
        fail(`GET Range 也失败: ${e2.message}`);
      }
    }
    break; // 只验证一个源的 URL 即可
  } else if (typeof url === 'string' && /^https?:/.test(url)) {
    logInfo('跳过 URL 连通性校验；如需验证真实可访问性，请追加 --verify-url');
    break;
  }
}

// ─── 总结 ─────────────────────────────────────────────
printSummary();
