# 开心动听 (Harmony Music)

一款基于 HarmonyOS 的开源音乐播放器，支持本地音乐播放、在线音乐探索、自定义音源脚本、百度网盘导入等功能，同时适配手机与车机（HiCar/CarLife）双模式。

## 功能特性

### 音乐播放
- 支持多种音频格式：MP3、FLAC、WAV、M4A、AAC、OGG、APE、AMR
- 播放模式：顺序播放、随机播放、单曲循环
- 播放集合：全部歌曲、收藏、按专辑、按歌手、自定义播放列表
- AVSession 系统集成：媒体控制中心、锁屏控制
- LiveView（灵动岛）：实时显示播放状态和歌词
- 后台播放：长驻后台任务 + 通知

### 在线音乐
- 内置五大平台榜单浏览与搜索：酷我、酷狗、腾讯、网易、咪咕
- 自定义音源系统：兼容 LX Music 音源脚本格式，通过 QuickJS 引擎执行
- 在线歌词获取，支持 LRC 格式解析

### 歌词系统
- LRC 格式歌词解析
- 逐字歌词（lxlyric）
- 翻译歌词（tlyric）、罗马音歌词（rlyric）
- 歌词自动修复（模糊匹配搜索）

### 百度网盘集成
- OAuth 授权登录
- 目录浏览与音频文件下载导入

### 其他
- 主题系统：浅色 / 深色 / 跟随系统
- 国际化：中文 / 英文
- 车机模式：HiCar / CarLife 投屏，横屏 UI
- 数据持久化：SQLite 数据库，支持从旧版 Preferences 自动迁移

## 技术栈

| 层面 | 技术 |
|------|------|
| 平台 | HarmonyOS (API 22, SDK 6.0.2) |
| 语言 | ArkTS (ETS) — 鸿蒙声明式 UI 框架 |
| 原生层 | C++17 + NAPI (Node-API 风格的原生桥接) |
| JS 引擎 | QuickJS (嵌入 C++ 原生层，用于执行音源脚本) |
| 构建系统 | Hvigor (鸿蒙官方构建工具) |
| 包管理 | OHPM |
| 数据库 | SQLite (relationalStore / @kit.ArkData) |
| 媒体播放 | AVPlayer (@kit.MediaKit) |
| 网络 | @kit.NetworkKit |

## 项目结构

```
harmony-music/
├── AppScope/                          # 应用级作用域配置
│   ├── app.json5                      # 应用全局配置 (bundleName, version)
│   └── resources/                     # 应用级资源
├── entry/                             # 主模块 (HAP)
│   ├── src/main/
│   │   ├── cpp/                       # C/C++ 原生代码
│   │   │   ├── napi_init.cpp          # NAPI 桥接层 — QuickJS 引擎管理
│   │   │   ├── CMakeLists.txt         # CMake 构建配置
│   │   │   └── quickjs/              # QuickJS JavaScript 引擎源码
│   │   ├── ets/                       # ArkTS 源码 (主要业务逻辑)
│   │   │   ├── pages/
│   │   │   │   └── Index.ets         # 主页面入口
│   │   │   ├── components/            # UI 组件
│   │   │   │   ├── car/              # 车机模式组件
│   │   │   │   ├── explore/          # 音乐厅/探索页组件
│   │   │   │   ├── home/             # 首页/播放队列组件
│   │   │   │   ├── profile/          # 个人中心组件
│   │   │   │   ├── shell/            # 外壳/全局 UI 组件
│   │   │   │   └── source/           # 音源管理组件
│   │   │   ├── constants/
│   │   │   │   └── AppConstants.ets  # 全局常量定义
│   │   │   ├── models/
│   │   │   │   └── AppModels.ets     # 数据模型/类型定义
│   │   │   ├── services/             # 业务服务层
│   │   │   │   ├── AppStatePersistenceService.ets    # 状态持久化 (SQLite)
│   │   │   │   ├── BaiduPanService.ets               # 百度网盘 API
│   │   │   │   ├── CustomPlaylistService.ets         # 自定义播放列表
│   │   │   │   ├── CustomSourceCatalogService.ets    # 音源目录管理
│   │   │   │   ├── MusicSourceApiService.ets         # 音乐源 API (榜单/搜索)
│   │   │   │   ├── PlaybackPlatformService.ets       # 播放平台集成
│   │   │   │   ├── QuickJsSourceService.ets          # QuickJS 音源服务
│   │   │   │   ├── SourceLyricsService.ets           # 歌词获取服务
│   │   │   │   └── TrackArtworkService.ets           # 音轨封面/元数据提取
│   │   │   ├── utils/                # 工具函数
│   │   │   │   ├── LibraryStateUtils.ets             # 音乐库状态工具
│   │   │   │   ├── LxUserApiPreload.ets              # LX 音源预加载脚本
│   │   │   │   ├── LyricsParser.ets                  # LRC 歌词解析器
│   │   │   │   ├── MusicSourceUtils.ets              # 音源工具函数
│   │   │   │   ├── PlaybackCollectionUtils.ets       # 播放集合工具
│   │   │   │   ├── QuickJsEngine.ets                 # QuickJS 引擎适配器
│   │   │   │   ├── ThemeUtils.ets                    # 主题/调色板工具
│   │   │   │   └── TrackUtils.ets                    # 音轨工具函数
│   │   │   ├── types/
│   │   │   │   └── libentry.d.ts     # 原生模块类型声明
│   │   │   └── entryability/
│   │   │       └── EntryAbility.ets  # 应用 Ability 入口
│   │   └── resources/                # 资源文件 (图标/字符串/颜色/多语言)
│   └── module.json5                  # 模块配置
├── doctor/                           # 设计文档
│   └── custom-source-design.md       # 自定义音源架构设计文档
├── tools/
│   └── generate_app_icon.py          # 应用图标生成脚本
├── build-profile.json5               # 构建配置
└── oh-package.json5                  # 根包配置
```

## 架构设计

### 整体架构

应用采用**单页面 + 组件化**架构，所有 UI 逻辑集中在 `Index.ets` 主页面，通过子组件拆分实现模块化。页面通过 `MainTab` 枚举切换三个主 Tab：Home（播放）、Explore（音乐厅）、Profile（我的），同时支持车机模式横屏布局。

```
┌─────────────────────────────────────────────────────┐
│                   Index (主页面)                      │
│                                                      │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐           │
│  │  Home    │  │ Explore  │  │ Profile  │           │
│  │ (播放)   │  │ (音乐厅) │  │ (我的)   │           │
│  └──────────┘  └──────────┘  └──────────┘           │
│                                                      │
│  ┌─────────────────────────────────────────────┐     │
│  │  MiniPlayerBar / LyricsPanel / Navigation   │     │
│  └─────────────────────────────────────────────┘     │
└─────────────────────────────────────────────────────┘
```

### 分层架构

```
┌───────────────────────────────────────────────────┐
│  UI 层 (components/)                               │
│  声明式 UI 组件，通过 @State 驱动视图更新           │
├───────────────────────────────────────────────────┤
│  页面层 (pages/Index.ets)                          │
│  状态管理 + 业务逻辑编排 + 子组件组合               │
├───────────────────────────────────────────────────┤
│  服务层 (services/)                                │
│  各业务领域服务：播放、音源、歌词、网盘、持久化      │
├───────────────────────────────────────────────────┤
│  工具层 (utils/)                                   │
│  纯函数工具：解析器、引擎适配、主题计算             │
├───────────────────────────────────────────────────┤
│  原生层 (cpp/)                                     │
│  QuickJS 引擎 + NAPI 桥接 + zlib 解压              │
└───────────────────────────────────────────────────┘
```

### 自定义音源系统（QuickJS 沙箱）

这是本项目的核心创新点。通过在 C++ 原生层嵌入 QuickJS 引擎，实现了与 Desktop 版 LX Music 的音源生态兼容。

```
┌───────────────────────────────────────────────────┐
│  ArkTS 宿主层                                      │
│  QuickJsEngine.ets → loadSource / dispatch         │
│  QuickJsSourceService.ets → 音源交互协议            │
├─────────────── NAPI 桥接 ─────────────────────────┤
│  C++ 原生层 (napi_init.cpp)                        │
│  QuickJS C 引擎：创建/加载/分发/事件循环            │
├─────────────── JS 沙箱 ───────────────────────────┤
│  预加载脚本 (LxUserApiPreload.ets)                 │
│  globalThis.lx API + Buffer + crypto + setTimeout  │
├───────────────────────────────────────────────────┤
│  用户音源脚本                                      │
│  lx.send('inited', {sources}) → 声明能力           │
│  lx.on('request', handler) → 处理 musicUrl/lyric   │
│  lx.request(url, opts, cb) → HTTP 请求             │
└───────────────────────────────────────────────────┘
```

**数据流**：

1. 用户导入音源脚本 → JSDoc 元数据提取 → 保存脚本
2. 激活音源 → QuickJS 执行脚本 → `lx.send('inited')` 返回能力声明
3. 播放请求 → `dispatch('request')` → 脚本处理 → `lx.request()` 发起 HTTP → NAPI 桥接回宿主层执行网络请求 → 返回音频 URL

**与 Desktop 版 LX Music 的对比**：

| 维度 | Desktop (Electron) | 鸿蒙 (本项目) |
|------|-------------------|---------------|
| 脚本引擎 | Electron BrowserWindow | QuickJS C NAPI |
| 进程模型 | 三进程 (Renderer ↔ Main ↔ UserApi) | 单进程 (ArkTS + C++ NAPI) |
| 沙箱机制 | contextIsolation + CSP | QuickJS 沙箱 + eval 禁用 |
| HTTP 处理 | Node.js needle 库 | 宿主侧 HarmonyOS http 模块 |
| 事件通信 | IPC | QuickJS bridge + Promise 事件循环 |

### 状态管理

采用 HarmonyOS ArkUI 内置的状态管理机制：

- **@State 装饰器**：主页面中定义约 60 个响应式状态变量
- **@StorageProp**：通过 `AppStorage` 进行跨组件通信（如车机模式状态）
- **单向数据流**：子组件通过回调函数 (`onXxx`) 向父组件报告事件，父组件更新状态后通过属性传递给子组件

### 数据持久化

SQLite 数据库 (`local_music_player.db`) 包含 5 张表：

| 表名 | 用途 |
|------|------|
| `app_config` | 键值对配置存储 |
| `local_track` | 本地音轨数据 |
| `music_source_config` | 音源配置 |
| `music_source_script` | 音源脚本内容 |
| `playback_record` | 播放记录 |

支持从旧版 Preferences 格式自动迁移到 SQLite。

### 系统能力集成

| 能力 | 实现方式 |
|------|---------|
| 媒体会话 | AVSession — 系统媒体控制中心、锁屏控制 |
| 灵动岛 | LiveView — 实时显示播放状态和歌词 |
| 后台播放 | 长驻后台任务 (KEEP_BACKGROUND_RUNNING) + 通知 |
| 车机投屏 | HiCar / CarLife 能力声明，横屏 UI 适配 |
| 网络代理 | HTTP 请求自动重试（系统代理 → 直连） |

## 开发环境

### 前置条件

- [DevEco Studio](https://developer.huawei.com/consumer/cn/deveco-studio/) 5.0+
- HarmonyOS SDK API 22 (6.0.2)
- Node.js (OHPM 依赖)

### 构建与运行

1. 使用 DevEco Studio 打开项目根目录
2. 等待 OHPM 依赖安装完成
3. 连接 HarmonyOS 设备或启动模拟器
4. 点击 Run 运行应用

### 命令行构建

先准备 DevEco Studio 自带的 Node 和 hvigor 路径：

```bash
export DEVECO_NODE="<DevEco-Studio>/Contents/tools/node/bin/node"
export DEVECO_HVIGORW="<DevEco-Studio>/Contents/tools/hvigor/bin/hvigorw.js"
```

构建测试包（开发调试，使用 `develop + debug`）：

```bash
"$DEVECO_NODE" "$DEVECO_HVIGORW" \
	--mode module \
	-p module=entry@default \
	-p product=develop \
	-p buildMode=debug \
	-p requiredDeviceType=phone \
	assembleHap --analyze=normal --parallel --incremental --daemon
```

构建发布包（正式发布，使用 `publish + release`）：

```bash
"$DEVECO_NODE" "$DEVECO_HVIGORW" \
	--mode module \
	-p module=entry@default \
	-p product=publish \
	-p buildMode=release \
	-p requiredDeviceType=phone \
	assembleHap --analyze=normal --parallel --incremental --daemon
```

说明：

- `develop/debug` 用于本地开发、联调和测试包构建。
- `publish/release` 用于正式发布包构建。
- 当前工程仍保留 `default` product 作为 hvigor 兼容入口，但推荐直接使用上面两套显式命令。

### 项目配置

- **Bundle Name**: `com.opensource.metis.music`
- **应用名称**: 开心动听
- **支持设备**: phone, car
- **最低 API**: 22
- **签名配置**: 见 `build-profile.json5`

## 致谢

- [LX Music](https://github.com/lyswhu/lx-music-desktop) — 自定义音源脚本格式与协议设计
- [QuickJS](https://bellard.org/quickjs/) — Fabrice Bellard & Charlie Gordon 的嵌入式 JavaScript 引擎

## 许可证

本项目基于 [Apache License 2.0](LICENSE) 开源。

QuickJS 引擎源码 (`entry/src/main/cpp/quickjs/`) 基于 MIT 许可证，版权归 Fabrice Bellard & Charlie Gordon 所有。
