# Changelog

本项目（HarmonyNAS 鸿蒙原生版）遵循 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.0.0/) 规范，
版本号遵循 [Semantic Versioning](https://semver.org/lang/zh-CN/)。

**特别说明：本项目是基于原 Android NAS 架构思想，完全使用纯血 ArkTS 从零重构的独立鸿蒙原生项目。**
本项目不继承原 Android 版本的历史迭代轨迹，当前发布的 `v1.0.0` 是作为独立鸿蒙生态项目的起始版本。

以下是初始版本的完整功能说明：

---

## [1.0.0] - 2026-10-23

**🚀 鸿蒙创世版：原生重构与多设备生态大满贯**

这是 HarmonyNAS 作为一个独立鸿蒙项目的首个正式版本。我们彻底抛弃了 Java 与历史包袱，完全基于 HarmonyOS NEXT (API 12) 的原生能力，实现了从底层通信协议到前端多端适配的全面重构。

### Added (服务端 - 纯手写协议栈与沙箱调度)
- **手写 HTTP/1.1 框架**：在 `HttpServer.ets` 中，基于 `@kit.NetworkKit` 的 `TCPSocketServer` 从零实现了 HTTP 报文接收、Header 解析、Body 截取及 401 Basic Auth 鉴权。
- **流媒体与 Range 分片**：完美支持 `Range` 请求头。利用 `fileIo.readSync` 按 64KB 分块循环读取并发送，绝不将大文件读入内存，彻底杜绝 OOM。
- **WebDAV 协议完全体**：基于 TCP 框架手写解析 XML 报文，支持 `PROPFIND` (Depth 0/1), `PUT`, `DELETE`, `MKCOL` 等标准指令，可完美挂载至 Windows 资源管理器。
- **FTP 服务端原生实现**：纯手写 Socket 报文解析，支持 `PASV` 被动模式（动态分配 30000-30100 端口），完美绕过防火墙限制，兼容老旧播放器。
- **LocalSend 免装接收**：监听 `53317` 端口，底层实现 UDP 组播发现，并接管 HTTP 文件流式写入。文件自动落盘至 `/Download/LocalSend/`。
- **原生引擎接入**：接入 `@kit.BasicServicesKit` 的 `zlib` 模块，实现极速安全解压；手写 Multipart 边界解析器，支持多文件表单上传。
- **沙箱安全防线**：路径严格限制在 `context.filesDir`，底层实现 `PathUtils` 拦截器，任何 `..` 穿越尝试会被强行拦截。

### Added (客户端 - 一套代码，全设备运行)
- **全设备自适应引擎 (DeviceAdapter)**：通过 `mediaquery` 与 `deviceInfo` 自动匹配布局形态。
  - 手机端：单栏瀑布流 + 底部 Tab。
  - 平板/2in1 端：左侧 SideBar 固定导航 + 右侧多列网格双栏布局。
  - TV / 手表端：全屏沉浸式网格，强制开启 `focusable`，重写 `onKeyEvent` 拦截方向键与表冠。
- **TV 遥控器焦点动画**：针对智慧屏开发 `FocusableCard` 组件，遥控器移动焦点时卡片自动放大 1.1 倍并带柔和阴影扩散。
- **相册增量备份**：利用 `photoAccessHelper` 扫描系统图库，对比服务端 `/Photos/` 目录文件名，只传新图，杜绝重复上传。
- **局域网并发扫描**：自动获取网卡子网，开启 64 线程并发探测 `8080` 端口，秒级发现局域网内所有 NAS 节点。
- **跨端剪贴板与全局搜索**：支持全端文本复制粘贴；支持深度为 6 层的多线程全盘文件遍历搜索。

### Added (Web 网页端 - 沉浸式管理与广告生态)
- **Material Design 3 UI**：重写前端，全局采用 CSS 变量系统，操作收纳进 Bottom Sheet 底部面板，支持 401 全局 Fetch 拦截。
- **完整的广告分发机制**：引入 `AdManager` 双引擎架构。在开屏、文件列表顶/底、主菜单、预览弹窗预留 5 大广告位。支持本地素材(`local`)与华为鲸鸿动能(`petal`)下发，支持曝光/点击埋点上报。
- **免密分享短链**：内置 Token 映射机制，通过 `/share/{token}` 链接无需登录即可直接下载文件。

### Added (系统生命周期保活)
- **分布式长时任务**：在 `EntryAbility` 中正式向系统申请 `backgroundTaskManager` 的 `DATA_TRANSFER` 长时任务，配合通知栏常驻，彻底解决鸿蒙系统息屏冻结应用导致 Socket 断连的顽疾。

### 工具链与工程化
- **脚手架生成脚本**：提供 `scaffold.py` 与 `scaffold_client.py`，支持一键生成服务端与客户端的完整工程骨架。
- **自动化修补脚本**：提供 `fix_nas.py`，通过绝对路径直接修改现有 ArkTS 文件，解决痛点 Bug 或快速补齐新功能模块。

---
