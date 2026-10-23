# HarmonyNAS (鸿蒙全场景私有云 · 独立重构版)

[![Platform](https://img.shields.io/badge/Platform-HarmonyOS_NEXT%20%7C%20Web%20%7C%20Win%20%7C%20Linux-brightgreen.svg)]()
[![Min SDK Server](https://img.shields.io/badge/Server_Min_SDK-API_12-blue.svg)]()
[![Min SDK Client](https://img.shields.io/badge/Client_Min_SDK-API_12-blue.svg)]()
[![Language](https://img.shields.io/badge/Language-ArkTS%20%2F%20HTML-orange.svg)]()
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![AI Generated](https://img.shields.io/badge/AI_Generated-99%25-red.svg)](docs/AI_DISCLOSURE.md)

> **本项目是由《Android NAS》原作者亲自操刀，完全使用纯血 ArkTS 从零重构的独立鸿蒙原生项目。**
> 
> 原项目证明了「把吃灰手机变成全平台私有云」的可行性，创造了辉煌的十端生态闭环。而本项目作为作者在鸿蒙生态的全新独立探索，彻底抛弃了沉重的 Java 历史包袱与极客向的 Root 提权，全面拥抱 **HarmonyOS NEXT** 的安全沙箱与原生分布式能力。
> 
> 我们利用 `@kit.NetworkKit` 纯手写协议栈，在极低的内存占用下，带来了极致安全、合法、且完美契合鸿蒙系统的原生 NAS 体验。

**📌 当前版本：v1.0.0 (鸿蒙创世版)** 
这是本独立项目在鸿蒙生态的起点，也是作者多端矩阵的又一重磅新作。目前已完美实现原项目最核心的文件流转、多协议互通与多设备自适应能力。

---

## ⚠️ 关于 AI 生成代码的严正声明（务必阅读）

与原 Android 项目一脉相承，**本项目在开发过程中深度使用了大型语言模型（LLM）辅助生成代码。项目中 99% 以上的核心代码（包括 ArkTS、HTML、CSS、Python 脚本等）均由 AI 直接输出，人类开发者（也就是原作者）主要担任“产品经理”与“测试工程师”的角色。**

- **代码可用性**：AI 生成的 ArkTS 代码（尤其是纯手写的 `TCPSocketServer` HTTP 状态机、WebDAV XML 解析、FTP PASV 握手逻辑）经过了真机编译与物理设备的反复验证，但不排除在边缘场景（如极端网络延迟、非标报文）下存在隐藏 Bug。
- **包体与冗余**：AI 有时会生成冗长的防御性代码，请自行进行代码审查（Code Review）。
- **开发者工作**：原作者的日常主要是编写 Prompt、在 DevEco Studio 中执行 `hvigorw assembleHap`、把编译出来的 HAP 包装到手机/平板/TV 上，然后拿着截图或报错日志去找 AI 输出补丁（例如项目根目录下的 `fix_nas.py` 就是 AI 生成的热修复脚本）。
- **详细披露**：请查阅 **[AI 生成声明 (AI_DISCLOSURE.md)](docs/AI_DISCLOSURE.md)** 了解 AI 参与的具体模块与人类开发者的真实工作量。

*如果你在使用过程中遇到玄学报错，请不要怀疑自己，大概率是 AI 的锅。欢迎提交 Issue，我会带着报错日志继续去找 AI 修。*

---

## 📚 全局文档矩阵 (Documentation)

本项目拥有极其详尽的文档体系，帮助你在鸿蒙生态下完成从零部署到深度开发的所有工作：

- 📖 **[终极使用与运维指南 (USAGE.md)](docs/USAGE.md)**：
  从零部署、多协议映射（WebDAV/FTP）、鸿蒙客户端实操、相册备份与极端故障排查。这是你上手鸿蒙 NAS 的第一站。
- 🔌 **[开发者 API 接口规范 (API_DOC.md)](docs/API_DOC.md)**：
  包含 8080 端口的所有 HTTP JSON API 细节、WebDAV 底层报文规范、FTP 控制流与 LocalSend 协议。
- 🏗️ **[底层架构深度解析 (ARCHITECTURE.md)](docs/ARCHITECTURE.md)**：
  深入剖析 ArkTS 下的 `TCPSocketServer` 手写协议栈、多设备自适应决策树、沙箱防穿越机制以及长时任务保活原理。
- 🛡️ **[安全策略与高危警告 (SECURITY.md)](SECURITY.md)**：
  **（必读）** 鸿蒙沙箱权限说明、局域网明文传输风险及网络暴露防护建议。
- 🤖 **[AI 生成声明 (AI_DISCLOSURE.md)](docs/AI_DISCLOSURE.md)**：
  关于本项目 99% 代码由大模型生成的真实开发流程与局限性声明。
- 📝 **[版本更新日志 (CHANGELOG.md)](CHANGELOG.md)**：
  追溯项目 v1.0.0 初始版本的完整功能发布。

---

## 🌟 为什么独立开发鸿蒙版？（架构进化与设计哲学）

作为原 Android NAS 的作者，我深知旧架构的妥协与痛点。原项目为了追求极限兼容（甚至支持 API 8）以及极客特权（Root 全盘、H264 远控），采用了大量的底层 Hack（如静音音频欺骗保活、1 像素 Activity 提权）与第三方重型容器（如 NanoHTTPD）。

而在鸿蒙重构版中，我选择了**面向未来、拥抱原生**的全新架构。这并非一次简单的代码翻译，而是一次底层的刮骨疗毒：

### 1. 纯血手写，拒绝臃肿
为了保证极致的启动速度与极低的包体，本项目**绝不引入任何第三方库**。从 HTTP/1.1 状态机、WebDAV 的 XML 解析，到 FTP 的被动模式（PASV）握手，全部基于鸿蒙底层 `TCPSocketServer` 纯手写实现。这不仅让 HAP 包体极小，更让我们对每一个底层字节流拥有绝对的掌控力。

### 2. 合法长时任务，告别流氓保活
彻底摒弃原版饱受争议的“后台黑科技”。我们利用鸿蒙官方的 `backgroundTaskManager` 申请 `DATA_TRANSFER` 权限，配合通知栏常驻，合法合规地实现熄屏后的后台持续监听。既保证了 NAS 的可用性，又完美契合了鸿蒙系统的资源调度规范。

### 3. 绝对安全，沙箱隔离与防穿越
与 Android 版打破沙盒的“全盘模式”不同，鸿蒙版的根目录严格锁定在应用沙箱 `context.filesDir`。
但这并不意味着功能缩减。我们在底层 `PathUtils` 实现了极其严苛的**防路径穿越拦截器**。任何企图通过 `../` 跳出 NAS 根目录的恶意请求，都会被瞬间掐断，确保你在分享文件、开放 WebDAV 时的绝对安全。

### 4. 一套代码，全场景原生自适应 (Responsive UI)
旧版客户端分为 Android、TV、Watch 三个独立工程。而在鸿蒙版中，我编写了 `DeviceAdapter` 决策引擎。通过 `mediaquery` 与 `deviceInfo`，**同一套 ArkTS 代码**在手机上呈现为底部 Tab 栏，在平板/2in1 上呈现为左侧导航双栏布局，在智慧屏（TV）上则瞬间变为由遥控器焦点驱动的全屏瀑布流网格。

---

## ✨ 核心功能矩阵 (v1.0.0 独立版)

### 📱 服务端 (Server - 装在闲置鸿蒙设备)
- **多端口并发调度引擎**：
  - `8080`：Web 网页管理 / JSON API / 流媒体分片下载。
  - `8081`：标准 WebDAV 协议（纯 Socket 手写实现，支持 `PROPFIND`/`PUT`/`DELETE`/`MKCOL` 等）。
  - `2121`：原生 FTP 服务（支持 `PASV` 被动模式，兼容老旧电视与 Windows 资源管理器）。
  - `53317`：LocalSend 接收端（UDP 组播发现与 HTTP 接收，免装 App 互传文件）。
- **原生解压与秒传**：集成 `@kit.BasicServicesKit` 的 `zlib`，实现极速安全的 ZIP 在线解压；配合 `relationalStore` 记录文件哈希，实现客户端上传秒传。
- **核心驾驶舱**：基于 ArkUI 构建的控制台，支持自定义设备别名、一键开关各项服务、动态修改端口与管理员密码。

### 🖥️ 鸿蒙客户端 (Client - 随身控制中心)
- **多端响应式布局引擎**：
  - **手机端**：单栏瀑布流 + 底部 NavigationBar。
  - **平板/2in1 端**：左侧 SideBar 导航 + 右侧多列文件网格（双栏 Split 布局）。
  - **TV/手表端**：强制开启 `focusable`，重写 `onKeyEvent` 拦截方向键与表冠，焦点移动时卡片自动放大 1.1 倍。
- **相册自动增量备份**：利用 `photoAccessHelper` 扫描系统图库，与 NAS `/Photos/` 目录文件名秒级比对。只传新图，杜绝重复消耗流量。
- **局域网免输入扫描**：自动获取网卡子网，开启 64 线程并发探测 8080 端口，一键发现并连接局域网内的所有 NAS 节点。
- **全局搜索与剪贴板**：支持 6 层深度的多线程全盘文件遍历搜索；支持全端跨设备文本复制粘贴。

### 🌐 Web 网页端 (MD3 风格)
- **UI 革命**：全面采用 Material Design 3 设计规范，引入 CSS 变量系统。所有操作收纳进顺滑的 Bottom Sheet 底部面板。
- **流媒体与工具**：后端完美支持 `Range` 分片，前端随意拖动进度条秒开视频；支持 ZIP 在线解压、Web 剪贴板、免密分享短链。
- **原生广告分发**：内置 5 大广告展示位（开屏、列表顶/底、主菜单、预览弹窗）。底层抽象 `AdProvider` 接口，无缝支持本地素材（`local`）与华为鲸鸿动能（`petal`）双引擎下发。

---

## 🛠 兼容性与底层架构对比

| 对比维度 | 原版 [Android NAS](https://github.com/styisme/android-nas) | 本项目 (HarmonyNAS 鸿蒙独立版) |
|---|---|---|
| **最低兼容环境** | Android 2.2 (API 8) | HarmonyOS NEXT (API 12) |
| **核心开发语言** | Java + NanoHTTPD | **纯血 ArkTS + TCPSocketServer** |
| **后台保活方式** | 静音欺骗 + 1px Activity + Root 注入 | **系统级长时任务 (DATA_TRANSFER)** |
| **文件权限控制** | 突破沙盒 (Root 全盘访问 `/system`) | **严格沙箱隔离 + 防路径穿越拦截** |
| **屏幕远控功能** | H264 推流 + 无障碍触控注入 | **已剥离（聚焦纯粹、安全的文件流转）** |
| **客户端适配逻辑** | 分端开发 (Android/TV/Watch 三套代码) | **一套 ArkTS 代码，全设备响应式自适应** |
| **代码产出方式** | 99% 由 AI 生成 | **99% 由 AI 生成 (延续祖传手艺)** |
| **开源协议** | MIT License | MIT License |

---

## 📂 鸿蒙工程结构树

```text
HarmonyNAS-server/
├── entry/src/main/ets/
│   ├── entryability/
│   │   └── EntryAbility.ets           # 申请长时任务 + 启动核心服务
│   ├── model/
│   │   ├── HttpTypes.ets              # HTTP 报文结构定义
│   │   └── AdTypes.ets                # 广告数据模型
│   ├── service/
│   │   ├── HttpServer.ets             # 基于 TCPSocket 的手写 HTTP/1.1 服务器
│   │   ├── NasApiRouter.ets           # HTTP 路由分发与核心业务逻辑
│   │   ├── WebDavServer.ets           # 纯 Socket 实现的 WebDAV 报文解析
│   │   ├── FtpServer.ets              # 纯 Socket 实现的 FTP 控制流
│   │   ├── LocalSendServer.ets        # LocalSend 接收与 PIN 校验
│   │   └── NasService.ets             # 服务编排调度器
│   ├── manager/
│   │   ├── AuthManager.ets            # Basic Auth 鉴权
│   │   ├── DatabaseManager.ets        # 关系型数据库 (relationalStore)
│   │   ├── SettingsManager.ets        # 键值型配置 (preferences)
│   │   ├── VersionManager.ets         # 版本号读取
│   │   └── AdManager.ets              # 广告数据装配
│   ├── utils/
│   │   ├── PathUtils.ets              # 沙箱路径映射 + 防穿越机制
│   │   └── HttpUtils.ets              # 报文解析 + Multipart 手写解析
│   └── pages/
│       └── Index.ets                  # 服务端本地驾驶舱 UI
├── AppScope/                          # 应用全局配置
└── build-profile.json5                # 编译配置
```

---

## 🔗 作者寄语

作为两个项目的开发者，我致力于探索不同系统生态下的极限可能性：
- **[Android NAS](https://github.com/styisme/android-nas)**：主打**极限兼容与极客特权**，是玩机党的终极玩具。
- **[HarmonyNAS](本项目)**：主打**现代生态与安全原生**，是鸿蒙用户的全能私有云。

顺便一提，我的开发日常就是：打开对话框 -> 描述需求 -> 复制 AI 生成的几千行 ArkTS 代码 -> 覆盖到 DevEco -> 编译 -> 真机测试 -> 遇错 -> 复制报错日志发给 AI -> 循环。**本项目不仅是一个 NAS，它也是大模型在鸿蒙生态工程化落地的极限压力测试。**

如果你喜欢这个项目，欢迎在 GitHub 上点一个 Star ⭐️。你的支持是我持续迭代、继续用 AI 重构更多端的动力！

---

## 协议

本项目使用 [MIT License](LICENSE)。自由修改，任意分发。