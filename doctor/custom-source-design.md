# 鸿蒙自定义音源完美解析方案

> 基于 desktop/lx-music 自定义音源实现分析，结合当前鸿蒙应用已有架构，提出完整的改进方案。

---

## 一、Desktop 端架构分析

### 1.1 核心文件

| 文件 | 职责 |
|------|------|
| `src/main/modules/userApi/renderer/preload.js` | 预加载脚本，在沙箱 BrowserWindow 中暴露 `window.lx` API |
| `src/main/modules/userApi/utils.ts` | 脚本解析（JSDoc 元数据提取）、gzip 压缩存储 |
| `src/main/modules/userApi/main.ts` | 创建隐藏 BrowserWindow，IPC 通信 |
| `src/main/modules/userApi/rendererEvent/rendererEvent.ts` | 主进程事件路由：init / response / request |
| `src/main/modules/userApi/index.ts` | 对外 API：importApi / removeApi / setApi |
| `src/common/types/user_api.d.ts` | 类型定义 |

### 1.2 架构三进程模型

```
┌────────────────────────────────────────────┐
│  主窗口 Renderer (Vue)                      │
│  - UserApiModal.vue: 导入/删除/选择音源     │
│  - useInitUserApi.ts: 构建 getMusicUrl 等   │
│  - api-source.js: 路由请求到 userApi        │
├────────────────────────────────────────────┤
│         ipcRenderer ↕ ipcMain               │
├────────────────────────────────────────────┤
│  Main Process (Node.js)                     │
│  - importApi(): 解析元数据 + gzip + 存储    │
│  - setApi(id): 关闭旧窗口 → loadApi(id)    │
│  - loadApi(): createWindow() → 发送脚本     │
│  - request(): Promise 队列 + 20s 超时       │
│  - handleInit(): 校验 sources → 通知主窗口  │
│  - handleResponse(): resolve/reject 队列    │
├────────────────────────────────────────────┤
│         webContents.send ↕ ipcRenderer      │
├────────────────────────────────────────────┤
│  UserApi BrowserWindow (隐藏沙箱)           │
│  - contextIsolation: true                   │
│  - nodeIntegration: false                   │
│  - CSP: default-src 'none'                  │
│  - preload.js 通过 contextBridge 暴露 lx    │
│  - 脚本通过 webFrame.executeJavaScript 执行  │
└────────────────────────────────────────────┘
```

### 1.3 Desktop 预加载脚本完整 API

| API | 实现方式 | 说明 |
|-----|---------|------|
| `lx.version` | `'2.0.0'` | API 版本 |
| `lx.env` | `'desktop'` | 运行环境 |
| `lx.EVENT_NAMES` | `{request, inited, updateAlert}` | 事件名常量 |
| `lx.currentScriptInfo` | `{name, description, version, author, homepage, rawScript}` | 脚本元信息 |
| `lx.request(url, opts, cb)` | Node.js `needle` 库 | HTTP 请求，支持 proxy |
| `lx.send('inited', info)` | IPC → main process | 声明支持的 sources/actions/qualitys |
| `lx.send('updateAlert', data)` | IPC → main process | 显示更新提示 |
| `lx.on('request', handler)` | 注册回调 | 处理 musicUrl/lyric/pic 请求 |
| `lx.utils.crypto.aesEncrypt(buf, mode, key, iv)` | Node.js `createCipheriv` | AES 加密 |
| `lx.utils.crypto.rsaEncrypt(buf, key)` | Node.js `publicEncrypt` + RSA_NO_PADDING | RSA 加密 |
| `lx.utils.crypto.randomBytes(size)` | Node.js `crypto.randomBytes` | 安全随机数 |
| `lx.utils.crypto.md5(str)` | Node.js `createHash('md5')` | MD5 摘要 |
| `lx.utils.buffer.from(...args)` | Node.js `Buffer.from` | Buffer 创建 |
| `lx.utils.buffer.bufToString(buf, format)` | Node.js `Buffer.toString` | Buffer 转字符串 |
| `lx.utils.zlib.inflate(buf)` | Node.js `zlib.inflate` | zlib 解压 |
| `lx.utils.zlib.deflate(data)` | Node.js `zlib.deflate` | zlib 压缩 |

### 1.4 Desktop 脚本元数据解析

**仅从 JSDoc 注释块提取元数据**，不做任何静态变量解析：

```typescript
// utils.ts
const parseScriptInfo = (script: string) => {
  const result = /^\/\*[\S|\s]+?\*\//.exec(script)  // 匹配首个 /* ... */ 块
  if (!result) throw new Error('无效的自定义源文件')
  let scriptInfo = matchInfo(result[0])  // 提取 @name @version 等
  scriptInfo.name ||= `user_api_${new Date().toLocaleString()}`
  return scriptInfo
}
```

提取的字段及长度限制：

| 字段 | 最大长度 |
|------|---------|
| `@name` | 24 |
| `@description` | 36 |
| `@author` | 56 |
| `@homepage` | 1024 |
| `@version` | 36 |

**关键设计**：Desktop 端**不从脚本代码解析** `API_URL`、`API_KEY`、`MUSIC_QUALITY` 等变量。这些信息完全由脚本执行后通过 `lx.send('inited', {sources: {...}})` 动态返回。

### 1.5 Desktop 脚本执行与 init 流程

```
1. 用户导入 .js → parseScriptInfo() 提取 JSDoc 元数据
2. 生成 ID: user_api_{random3}_{timestamp}
3. gzip 压缩脚本 → base64 → 前缀 gz_ → electron-store 存储
4. 用户激活该音源 → setApi(id)
5. 关闭旧 BrowserWindow → createWindow()
6. BrowserWindow ready-to-show → 发送 initEnv 事件
7. preload.js 收到 → contextBridge 暴露 lx → executeJavaScript(script)
8. 脚本执行，调用 lx.send('inited', {sources: {kw: {type:'music', actions:['musicUrl'], qualitys:[...]}}})
9. preload handleInit() → 校验 sources 白名单 → IPC 发送到主进程
10. 主进程 handleInit() → 更新 apiStatus → 通知主窗口 → UI 可用
```

### 1.6 Desktop musicUrl 请求流程

```
1. 播放器请求 → api-source.js 检测到 user_api 前缀
2. sendUserApiRequest({requestKey, data: {source, action:'musicUrl', info:{type, musicInfo}}})
3. IPC invoke → 主进程 request() → 新建 Promise，存入 requestQueue，设 20s 超时
4. sendEvent → 发送到 UserApi BrowserWindow
5. preload ipcRenderer.on('request') → handleRequest()
6. 调用脚本注册的 events.request({source, action, info})
7. 脚本返回 Promise<url_string>
8. preload 校验 URL（string, ≤2048, /^https?:/）
9. IPC send('response', {requestKey, result, status:true})
10. 主进程 handleResponse → resolve Promise → 返回给播放器
```

### 1.7 Desktop 安全模型

| 措施 | 说明 |
|------|------|
| `contextIsolation: true` | 脚本与 preload 在不同 JS 上下文中 |
| `nodeIntegration: false` | 脚本无法访问 require/process |
| CSP `default-src 'none'` | 页面无法加载任何外部资源 |
| 禁止导航/新窗口/权限 | 防止脚本逃逸 |
| `contextBridge` 白名单暴露 | 仅暴露 `window.lx` 和错误处理器 |
| URL/长度校验 | musicUrl ≤ 2048, lyric ≤ 51200 等 |
| 请求超时 20s | 主进程侧强制超时 |
| 限制 sources 白名单 | 仅 kw/kg/tx/wy/mg/local |
| 限制 actions 白名单 | 仅 musicUrl/lyric/pic |
| 单次初始化 | `isInitedApi` 标志防止重复 init |

---

## 二、鸿蒙端当前实现分析

### 2.1 架构概览

```
┌───────────────────────────────────────────────────┐
│  Index.ets (UI + 全部业务逻辑)                     │
│  processAndAddSource / addMusicSourceFromFile/Url  │
│  loadSourceIntoJsEngine / requestMusicUrlFromEngine│
│  handleJsEngineInit / createQuickJsHttpRequestTask │
├───────────────────────────────────────────────────┤
│  QuickJsEngineAdapter (ets/utils/QuickJsEngine.ets)│
│  loadSource / dispatch / 事件循环                   │
│  host event routing: request/cancel/setTimeout     │
├───────────────────────────────────────────────────┤
│  LX_PRELOAD_SCRIPT (ets/utils/LxUserApiPreload.ets)│
│  1258 行纯 JS 字符串常量                            │
│  globalThis.lx / Buffer / console / setTimeout     │
├───────────────────────────────────────────────────┤
│  libentry.so (cpp/napi_init.cpp)                   │
│  QuickJS C 引擎 NAPI 桥接                          │
│  createEngine / loadSource / dispatch              │
└───────────────────────────────────────────────────┘
```

### 2.2 当前 API 兼容性表（对比 Desktop）

| API | Desktop | 鸿蒙 | 状态 |
|-----|---------|------|------|
| `lx.version` | `'2.0.0'` | `'2.0.0'` | ✅ 一致 |
| `lx.env` | `'desktop'` | `'mobile'` | ✅ 符合预期 |
| `lx.EVENT_NAMES` | ✅ | ✅ | ✅ 一致 |
| `lx.currentScriptInfo` | ✅ | ✅ | ✅ 一致 |
| `lx.request()` | needle (Node.js) | native bridge → HarmonyOS http | ✅ 功能一致 |
| `lx.send('inited')` | IPC | bridge → terminal event | ✅ 一致 |
| `lx.send('updateAlert')` | IPC | bridge → host event | ✅ 一致 |
| `lx.on('request')` | ✅ | ✅ | ✅ 一致 |
| `lx.utils.crypto.aesEncrypt` | `createCipheriv` | 纯 JS S-box | ✅ 功能一致(仅AES-128) |
| `lx.utils.crypto.rsaEncrypt` | `publicEncrypt` + NO_PADDING | 纯 JS BigInt | ✅ 功能一致 |
| `lx.utils.crypto.md5` | `createHash('md5')` | 纯 JS | ✅ 一致 |
| `lx.utils.crypto.randomBytes` | `crypto.randomBytes` (安全) | `Math.random()` | ⚠️ 不安全但可用 |
| `lx.utils.buffer` | Node.js Buffer | 纯 JS Uint8Array | ✅ 一致 |
| `globalThis.Buffer` | 原生 | polyfill | ✅ 一致 |
| `console` | 原生 | bridge → log | ✅ 一致 |
| `setTimeout/clearTimeout` | 原生 | bridge → host event → 调度 | ✅ 一致 |
| `atob/btoa` | 原生 | 纯 JS | ✅ 一致 |
| `globalThis.eval` | ✅ 可用 | `undefined` | ✅ 鸿蒙更安全 |
| `lx.utils.zlib` | Node.js zlib | ❌ **缺失** | 🔴 **需要补充** |
| AES 解密 | `createDecipheriv` (隐式可用) | ❌ **缺失** | 🟡 按需补充 |
| `setInterval` | 浏览器原生 | ❌ **缺失** | 🟡 按需补充 |

### 2.3 当前脚本解析流程的问题

当前 `MusicSourceUtils.ets` 的 `parseLxSourceScript()` 使用正则匹配：

```typescript
// 1. 匹配 const API_URL = "..." — 混淆脚本中不存在
let apiUrlMatch = script.match(/const\s+API_URL\s*=\s*["'`]([^"'`]+)["'`]/);

// 2. 匹配 const API_KEY = "..." — 混淆脚本中不存在
let apiKeyMatch = script.match(/const\s+API_KEY\s*=\s*[`"']([^`"']+)[`"']/);

// 3. 匹配 const MUSIC_QUALITY = JSON.parse('...') — 混淆脚本中不存在
let qualityMatch = script.match(/const\s+MUSIC_QUALITY\s*=\s*JSON\.parse\s*\(\s*'([^']+)'\s*\)/);
```

**问题核心**：这些正则对标准格式的脚本有效，但对混淆/压缩过的脚本完全无效。Desktop 端**根本不做这些解析**，完全依赖 `lx.send('inited')` 的返回值获取 sources 信息。

当前的缓解方案——当正则匹配失败时使用 `simpleHash` 和 `defaultMusicSources()` 作为后备——虽然能让脚本被添加，但 musicSources 信息不准确（用了默认值），且依赖脆弱的关键词检测 (`indexOf('globalThis')`)。

---

## 三、改进方案

### 3.1 总体思路

对齐 Desktop 端设计：**脚本的能力声明完全在运行时由 JS 引擎返回，不做任何静态代码分析**。

```
导入脚本          → JSDoc 元数据提取（保留，与 Desktop 一致）
                  → 临时保存脚本

激活/验证脚本     → QuickJS 执行脚本
                  → 脚本调用 lx.send('inited', {sources}) 返回能力声明
                  → 用 init 返回值更新 musicSources
                  → 持久化最终配置
```

### 3.2 修改一：简化 `parseLxSourceScript`

移除所有静态变量正则匹配，仅保留 JSDoc 注释解析（与 Desktop 完全一致）：

```typescript
// MusicSourceUtils.ets — 简化后
export function parseLxSourceScript(script: string): LxSourceParseResult {
  let info = parseLxSourceScriptInfo(script);  // 保留 JSDoc @name/@version 提取
  return {
    name: info['name'],
    description: info['description'],
    author: info['author'],
    homepage: info['homepage'],
    version: info['version'],
    // 以下字段不再从静态代码解析，全部由引擎 init 后动态获取
    apiUrl: '',
    apiKey: '',
    musicSources: []
  };
}
```

### 3.3 修改二：`processAndAddSource` 改为两阶段

**阶段 1（同步）**：快速注册，用于 UI 即时反馈

```typescript
private processAndAddSource(scriptContent: string): MusicSourceConfig | null {
  let info = parseLxSourceScriptInfo(scriptContent);  // 仅 JSDoc
  let scriptHash = simpleHash(scriptContent);

  // 去重检查
  let duplicated = this.musicSources.some(
    (s: MusicSourceConfig) => s.apiUrl === `script_${scriptHash}`
  );
  if (duplicated) {
    this.showToast('该音源已添加');
    return null;
  }

  let newSource: MusicSourceConfig = {
    id: `source_${Date.now()}_${Math.floor(Math.random() * 10000)}`,
    name: info['name'] || `user_api_${new Date().toLocaleString()}`,
    description: info['description'] || '',
    author: info['author'] || '',
    homepage: info['homepage'] || '',
    version: info['version'] || '1.0.0',
    allowShowUpdateAlert: true,
    apiUrl: `script_${scriptHash}`,
    apiKey: '',
    musicSources: defaultMusicSources()  // 临时默认值
  };

  this.musicSourceScripts.set(newSource.id, scriptContent);
  this.musicSources = this.musicSources.concat([newSource]);
  this.schedulePersistState();
  return newSource;
}
```

**阶段 2（异步）**：加载引擎验证脚本，用 init 返回值更新 musicSources

```typescript
private async validateAndActivateSource(source: MusicSourceConfig): Promise<boolean> {
  let loaded = await this.loadSourceIntoJsEngine(source);
  if (!loaded) {
    // init 失败 → 脚本无效，移除
    this.removeMusicSource(source.id);
    this.showToast(`音源「${source.name}」加载失败：${this.jsEngineLastError}`);
    return false;
  }
  // loadSourceIntoJsEngine → handleJsEngineInit 已更新 source.musicSources
  this.schedulePersistState();
  this.showToast(`已添加音源「${source.name}」`);
  return true;
}
```

调用方修改：

```typescript
// 当前：直接完成
if (this.processAndAddSource(scriptContent)) { ... }

// 改为：两阶段
let source = this.processAndAddSource(scriptContent);
if (source) {
  await this.validateAndActivateSource(source);
}
```

### 3.4 修改三：补充 `lx.utils.zlib`

Desktop 预加载脚本提供了 `lx.utils.zlib.inflate` 和 `lx.utils.zlib.deflate`。部分自定义脚本依赖此 API 处理 gzip 数据。

**方案**：在 LxUserApiPreload.ets 中添加纯 JS 的 inflate/deflate 实现。

可选实现策略：

**A. 纯 JS pako-lite（推荐）**

在预加载脚本中嵌入精简版 inflate/deflate（约 15KB 代码），支持 zlib 格式（RFC 1950）。

```javascript
// 在 lx.utils 中添加：
zlib: {
  inflate: function(buf) {
    return new Promise(function(resolve, reject) {
      try {
        resolve(zlibInflate(buf));  // 纯 JS Inflate 实现
      } catch (e) {
        reject(e);
      }
    });
  },
  deflate: function(data) {
    return new Promise(function(resolve, reject) {
      try {
        resolve(zlibDeflate(data));  // 纯 JS Deflate 实现
      } catch (e) {
        reject(e);
      }
    });
  }
}
```

**B. Native bridge 代理（备选）**

通过新增 bridge 动作 `'zlib_inflate'` / `'zlib_deflate'` 将数据传到宿主层，使用 HarmonyOS `zlib` 模块处理。缺点是需要异步往返，且大数据序列化开销大。

**推荐方案 A**：纯 JS 实现，零依赖，与 Desktop 行为完全一致。可使用成熟的开源 pako 库核心代码。

### 3.5 修改四：补充 `setInterval` / `clearInterval`

Desktop 运行在 Electron BrowserWindow 中，原生有 `setInterval`。当前鸿蒙预加载仅实现了 `setTimeout`。

在 LxUserApiPreload.ets 中基于现有 `setTimeout` 实现：

```javascript
var intervalCallbacks = {};
var intervalIdCounter = 1;

globalThis.setInterval = function(cb, ms) {
  var args = Array.prototype.slice.call(arguments, 2);
  var id = intervalIdCounter++;
  var wrappedCb = function() {
    try { cb.apply(null, args); } catch (e) { /* ignore */ }
    if (intervalCallbacks[id] != null) {
      intervalCallbacks[id] = setTimeout(wrappedCb, ms);
    }
  };
  intervalCallbacks[id] = setTimeout(wrappedCb, ms);
  return id;
};

globalThis.clearInterval = function(id) {
  if (intervalCallbacks[id] != null) {
    clearTimeout(intervalCallbacks[id]);
    delete intervalCallbacks[id];
  }
};
```

### 3.6 修改五：安全沙箱增强（对齐 Desktop 安全等级）

Desktop 通过 Electron `contextIsolation` 实现强隔离。鸿蒙 QuickJS 没有 context 隔离，但可以增加以下措施：

#### 5a. 保护关键全局属性

```javascript
// 在 lx_setup 末尾添加
var protectedNames = ['lx', '__lx_native__', '__quickjs_bridge__', '__quickjs_set_timeout__'];
for (var i = 0; i < protectedNames.length; i++) {
  Object.defineProperty(globalThis, protectedNames[i], {
    configurable: false,
    writable: false
  });
}
```

#### 5b. 代理 Function 构造器

```javascript
var OrigFunction = Function;
try {
  globalThis.Function = new Proxy(OrigFunction, {
    construct: function() { throw new Error('Function constructor is disabled'); },
    apply: function() { throw new Error('Function constructor is disabled'); }
  });
} catch (e) { /* Proxy 可能不可用 */ }
```

### 3.7 修改六（可选）：AES 解密支持

Desktop 端通过 Node.js `createCipheriv` 隐式支持所有 cipher 模式。虽然 Desktop 的 `lx.utils.crypto` 只暴露了 `aesEncrypt`，但在 Electron BrowserWindow 中脚本可以通过其他方式使用解密。

鸿蒙 QuickJS 中脚本无法访问宿主加密 API，如果有脚本依赖 AES 解密，需在预加载中补充逆向 S-box 和 InvMixColumns 实现。

**优先级**：较低。先分析实际使用的脚本是否需要，按需添加。

---

## 四、改进后的完整数据流

### 4.1 添加音源

```
用户操作（导入文件或粘贴URL）
    │
    ▼
下载/读取脚本内容
    │
    ▼
parseLxSourceScriptInfo(script)
    ├── 解析 /* @name ... @version ... */ 注释块
    └── 返回 {name, description, author, homepage, version}
    │
    ▼
processAndAddSource(scriptContent) [阶段1: 同步]
    ├── simpleHash(scriptContent) → 生成唯一标识
    ├── 去重检查
    ├── 创建 MusicSourceConfig（默认 musicSources）
    ├── 保存脚本内容到 musicSourceScripts Map
    └── 持久化
    │
    ▼
validateAndActivateSource(source) [阶段2: 异步]
    ├── loadSourceIntoJsEngine(source)
    │   ├── 拼接 setupScript = PRELOAD + lx_setup(key, scriptInfo) + userScript
    │   ├── QuickJsEngine.loadSource(engineKey, setupScript)
    │   │   └── C++ JS_Eval → 脚本执行
    │   │       └── 脚本调用 lx.send('inited', {sources: {...}})
    │   │           └── handleInit → bridge('init', payload)
    │   │               └── C++ terminal_events_ → Pump → Done
    │   └── handleJsEngineInit(payload)
    │       └── 从 sources 中提取各源的 actions/qualitys
    │       └── 更新 source.musicSources ← 真实值
    ├── 成功 → 持久化更新后的配置
    └── 失败 → 移除该源，提示用户
```

### 4.2 播放请求

```
播放器请求 musicUrl
    │
    ▼
requestMusicUrlFromEngine(source, track, quality)
    ├── loadSourceIntoJsEngine(source)  // 已加载则跳过
    ├── 构建 requestData:
    │   {requestKey, data: {source, action:'musicUrl', info:{type, musicInfo}}}
    ├── QuickJsEngine.dispatch(engineKey, 'request', JSON.stringify(requestData))
    │   ├── C++ InvokeNative → __lx_native__(key, 'request', data)
    │   ├── JS handleRequest() → events.request({source, action, info})
    │   ├── 脚本处理 → lx.request() 发HTTP → bridge('request', httpReq)
    │   ├── C++ Pump → Host event → ArkTS handleHostEvent
    │   ├── createQuickJsHttpRequestTask → HarmonyOS http.createHttp()
    │   │   └── 代理重试: 系统代理 → usingProxy:false
    │   ├── HTTP 响应 → dispatch('response', responseJson)
    │   ├── JS handleNativeResponse → 回调脚本
    │   ├── 脚本处理结果 → bridge('response', {requestKey, result:{url}})
    │   └── C++ terminal_events_ → Done
    └── 解析 url → 下载音频 → 播放
```

### 4.3 HTTP 请求代理重试

```
createQuickJsHttpRequestTask(req)
    │
    ▼
第1次: usingProxy = undefined (系统默认)
    ├── 成功 → 返回
    └── 代理错误 (2300035/2300052/2300056/2300007/2300999)
        │
        ▼
第2次: usingProxy = false (直连)
    ├── 成功 → 返回
    └── 失败 → 抛出错误
```

---

## 五、鸿蒙端 vs Desktop 端差异总结

### 5.1 架构差异

| 维度 | Desktop | 鸿蒙 | 说明 |
|------|---------|------|------|
| 脚本引擎 | Electron BrowserWindow | QuickJS C NAPI | 鸿蒙更轻量 |
| 进程模型 | 三进程 (Renderer ↔ Main ↔ UserApi Window) | 单进程 (ArkTS + C++ NAPI) | 鸿蒙简化 |
| 沙箱机制 | contextIsolation + CSP | QuickJS 沙箱 + eval 禁用 | 等效 |
| HTTP 处理 | Node.js needle 库（在 preload 中直接调用） | 宿主侧 HarmonyOS http 模块 | 鸿蒙更安全 |
| 脚本存储 | electron-store + gzip | HarmonyOS Preferences | 平台适配 |
| 事件通信 | IPC (ipcRenderer/ipcMain) | QuickJS bridge + Promise 事件循环 | 等效 |
| 代理支持 | tunnel 库 (httpOverHttp) | HarmonyOS `usingProxy` 参数 + 重试 | 等效 |

### 5.2 需修改的文件清单

| 文件 | 改动类型 | 内容 |
|------|---------|------|
| `ets/utils/MusicSourceUtils.ets` | 修改 | `parseLxSourceScript` 移除静态正则，仅保留 JSDoc 解析 |
| `ets/pages/Index.ets` | 修改 | `processAndAddSource` 改为两阶段；调用方改为 async |
| `ets/utils/LxUserApiPreload.ets` | 修改 | 添加 `lx.utils.zlib`；添加 `setInterval/clearInterval`；安全增强 |
| `cpp/napi_init.cpp` | 不修改 | 当前实现完备 |
| `ets/utils/QuickJsEngine.ets` | 不修改 | 当前实现完备 |

### 5.3 修改优先级

| 优先级 | 改动项 | 影响 | 工作量 |
|--------|--------|------|--------|
| **P0** | 移除静态正则，改为引擎 init 动态获取 | 混淆脚本兼容性 | 小 |
| **P0** | processAndAddSource 两阶段化 | 配合 P0 正则移除 | 小 |
| **P1** | 添加 `lx.utils.zlib` | 部分脚本依赖 zlib 解压 | 中 |
| **P1** | 添加 `setInterval/clearInterval` | 部分脚本依赖定时轮询 | 小 |
| **P2** | 安全沙箱增强 | 防御性措施 | 小 |
| **P3** | AES 解密/AES-256 支持 | 极少数脚本需要 | 中 |

---

## 六、预加载脚本 API 完整对照表

以下是确保鸿蒙端与 Desktop 端 **API 完全兼容** 需要达到的最终状态：

| API | Desktop 实现 | 鸿蒙当前 | 目标状态 |
|-----|-------------|---------|---------|
| `lx.version` | `'2.0.0'` | ✅ `'2.0.0'` | ✅ |
| `lx.env` | `'desktop'` | ✅ `'mobile'` | ✅ |
| `lx.EVENT_NAMES` | ✅ | ✅ | ✅ |
| `lx.currentScriptInfo` | ✅ | ✅ | ✅ |
| `lx.request(url, opts, cb)` | ✅ needle | ✅ native bridge | ✅ |
| `lx.send('inited', info)` | ✅ | ✅ | ✅ |
| `lx.send('updateAlert', data)` | ✅ | ✅ | ✅ |
| `lx.on('request', handler)` | ✅ | ✅ | ✅ |
| `lx.utils.crypto.aesEncrypt` | ✅ | ✅ | ✅ |
| `lx.utils.crypto.rsaEncrypt` | ✅ | ✅ | ✅ |
| `lx.utils.crypto.md5` | ✅ | ✅ | ✅ |
| `lx.utils.crypto.randomBytes` | ✅ 安全 | ⚠️ Math.random | ⚠️ 可用但非安全 |
| `lx.utils.buffer.from` | ✅ | ✅ | ✅ |
| `lx.utils.buffer.bufToString` | ✅ | ✅ | ✅ |
| `lx.utils.zlib.inflate` | ✅ Node.js | ❌ 缺失 | 🔴 **需添加** |
| `lx.utils.zlib.deflate` | ✅ Node.js | ❌ 缺失 | 🔴 **需添加** |
| `globalThis.Buffer` | ✅ 原生 | ✅ polyfill | ✅ |
| `globalThis.setTimeout` | ✅ 原生 | ✅ bridge | ✅ |
| `globalThis.clearTimeout` | ✅ 原生 | ✅ | ✅ |
| `globalThis.setInterval` | ✅ 原生 | ❌ 缺失 | 🟡 **需添加** |
| `globalThis.clearInterval` | ✅ 原生 | ❌ 缺失 | 🟡 **需添加** |
| `globalThis.console` | ✅ 原生 | ✅ bridge | ✅ |
| `globalThis.atob/btoa` | ✅ 原生 | ✅ 纯 JS | ✅ |
| `globalThis.eval` | ✅ 可用 | ✅ `undefined` | ✅ (鸿蒙更安全) |

---

## 七、结论

当前鸿蒙端已完成 QuickJS 集成的核心架构，大部分 API 与 Desktop 端一致。需要重点解决的问题按优先级排序：

1. **P0：消除静态正则解析**。这是 Desktop 端根本不会做、而鸿蒙端做了却导致混淆脚本无法正确解析的根源。改为两阶段处理：先 JSDoc 提取元数据，后引擎 init 动态获取 sources。改动量小，效果明显。

2. **P1：补充 `lx.utils.zlib`**。Desktop 通过 Node.js zlib 模块提供，鸿蒙需要纯 JS 实现。这是目前最大的 API 缺口。

3. **P1：补充 `setInterval/clearInterval`**。基于现有 `setTimeout` 即可实现，改动极小。

4. **P2：安全增强**。保护关键属性不被覆盖，代理 Function 构造器。

完成以上修改后，鸿蒙端将能够完美解析和运行与 Desktop 端兼容的自定义音源脚本。
