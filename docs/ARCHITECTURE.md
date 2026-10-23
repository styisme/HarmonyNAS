# HarmonyNAS 底层架构深度解析 (Architecture)

作为首个完全基于 **HarmonyOS NEXT (API 12)** 原生重构的局域网 NAS 系统，HarmonyNAS 并没有简单地将旧版 Java 代码进行翻译。作为原 Android 版的作者，我彻底抛弃了第三方重型容器（如 NanoHTTPD、Spring 等），完全依靠 ArkTS 的语言特性与鸿蒙系统的底层 Kit 能力，从零构建了一套**手写协议栈与沙箱自适应**架构。

本文档将深度剖析这套“99% 由 AI 生成，1% 靠人类测试”的系统，是如何在严格的沙箱限制下，榨干纯血鸿蒙性能的。

---

## 一、 核心容器调度与生命周期 (NasService)

服务端以 `UIAbility` 为宿主。在原 Android 版本中，为了保活我们使用了“静音音频欺骗”、“1像素 Activity 提权”等黑科技。而在鸿蒙生态中，系统对后台资源管控极度严厉，必须采用完全合法的长时任务机制。

1. **合法长时任务保活**：
   在 `EntryAbility.ets` 的 `onWindowStageCreate` 生命周期中，主动向系统申请 `backgroundTaskManager.ContinuousTaskRequest`。我们指定了 `backgroundMode: DATA_TRANSFER`（数据传输模式），并在通知栏生成常驻通知。这是系统允许应用退入后台或锁屏后，底层 `TCPSocketServer` 依然保持监听的唯一合法凭证。
2. **多线程并发调度**：
   `NasService.ets` 作为总调度编排器，在初始化完毕后，会并行拉起多个核心服务，它们运行在独立的异步任务中，互不阻塞：
   - `8080` 端口：`HttpServer` (处理 Web 前端与 JSON API 请求)。
   - `8081` 端口：`WebDavServer` (处理 Windows / Mac 的网络磁盘挂载)。
   - `2121` 端口：`FtpServer` (处理老旧电视盒子与资源管理器连接)。
   - `53317` 端口：`LocalSendServer` (处理 UDP 发现与 HTTP 免装互传)。

---

## 二、 纯血手写 HTTP/1.1 协议栈 (HttpServer.ets)

鸿蒙系统没有内置的 HttpServer 模块，引入第三方 Node.js 容器又会导致 HAP 包体过大且无法直接访问鸿蒙沙箱。因此，我让 AI 基于 `@kit.NetworkKit` 的 `TCPSocketServer` 实现了一个完整的应用层状态机。

### 1. TCP 字节流的粘包与截断处理
底层的 Socket 是没有任何边界的字节流，且由于 MTU 限制，大请求会被拆成多个包到达。`HttpServer.ets` 内部维护了一个 `Uint8Array` 动态缓冲区：
- 每次收到 `on('message')` 回调，将新的 ArrayBuffer 拼接至缓冲区。
- 利用自写的高效扫描算法寻找 `\r\n\r\n`，精准切分 HTTP Header 和 Body。
- 解析 Header 中的 `Content-Length`，精准等待 Body 接收完毕（解决粘包/半包），再触发路由处理。
- **GC 防御**：必须将每个 `TCPSocketConnection` 存入数组 `clients` 持有强引用，否则极易被鸿蒙 GC 回收，导致 `on('message')` 回调莫名其妙失效。

### 2. Range 分片流式发送 (防 OOM 的核心)
当网页端拖拽视频进度条时，会发送 `Range: bytes=0-1024` 请求头。
- 服务端没有使用 `fileIo.readSync` 一次性读完整个视频（这在鸿蒙上会瞬间触发 OOM 闪退），而是开启了一个 `while` 循环。
- 每次从文件的特定 `offset` 读取 64KB 的 `ArrayBuffer`，立刻通过 `client.send()` 发送给前端，随后清空该 Buffer。
- 这种方式**无论视频有多大（哪怕是 100GB），服务端的内存占用永远保持在几 MB 级别**，极其稳定。

### 3. Multipart 边界解析器 (HttpUtils.ets)
Web 端的文件上传采用 `multipart/form-data` 格式。我们在 `HttpUtils.ets` 中通过字符串 `split` 实现了手写的 Boundary 解析，将二进制流按切分线剥离出文件数据。没有任何第三方依赖，包体极小。

---

## 三、 原生协议拦截与解析 (WebDAV & FTP)

原项目为了全盘访问权限，使用了 Root 提权。鸿蒙版必须放弃该特权，但网络协议的兼容性不能丢。

### 1. 手写 WebDAV 报文 (WebDavServer.ets)
为了能被 Windows 资源管理器直接挂载为网络驱动器，系统复用了 TCP 框架，在 8081 端口独立解析 XML：
- 拦截到 `PROPFIND` 指令时，服务端递归遍历沙箱目录，手动拼接符合 DAV 规范的 `<D:multistatus>` XML 树，并设置 Header `Depth: 1`。
- 拦截到 `PUT` 指令时，剥离报文头，将剩余流式写入沙箱文件。
- 拦截到 `DELETE` 时，底层调用 `fileIo.rmdirSync` 执行原生递归删除。

### 2. FTP 控制流与 PASV 被动模式 (FtpServer.ets)
FTP 的难点在于**控制通道与数据通道分离**，以及老式防火墙的拦截。
- 客户端连接 2121 端口建立控制流后，发送 `PASV` 指令。
- 服务端会利用 `TCPSocketServer` 动态开启一个新的临时端口（从 30000 到 30100 轮询），并通过控制通道返回 `227 Entering Passive Mode`。
- 客户端随后连接该临时端口进行大文件传输。这种纯手写实现完美绕过了现代路由器与防火墙对主动模式的拦截。

---

## 四、 多设备自适应渲染引擎 (DeviceAdapter.ets)

这是鸿蒙端最核心的亮点，也是 AI 在 UI 层面做出的最复杂的逻辑判断。如何用一套 ArkTS 代码，同时跑在手机、平板和智慧屏上？

### 1. 断点与设备类型决策 (LayoutDecision)
- 启动时，通过 `mediaquery` 监听当前窗口宽度（vp），并结合 `deviceInfo.deviceType` 判断设备的物理形态。
- 核心决策树返回对应的布局参数：
  - **Phone**：单栏布局，`showBottomTabs: true`。
  - **Tablet / 2in1**：双栏 Split 布局，左侧固定 `SideBar`，右侧内容区网格列数设为 3-5。
  - **TV / Watch**：全屏沉浸式网格，无底部导航，强制开启焦点模式。

### 2. 焦点系统与遥控器适配 (FocusableCard.ets)
在 TV 端，传统的鼠标/触摸事件失效。我们在 `FocusableCard` 组件中：
- 开启 `.focusable(true)`。
- 监听 `.onFocus()` 和 `.onBlur()`，配合 `.scale({ x: 1.1, y: 1.1 })` 属性与 `.animation` 动画，实现极致的“卡片放大”效果。
- 监听 `.onKeyEvent()`，拦截遥控器的 `KEYCODE_ENTER` 或 `KEYCODE_DPAD_CENTER` 模拟确认点击。

---

## 五、 严格的安全沙箱与防穿越 (PathUtils.ets)

这是鸿蒙原生版与 Android 版最大的安全差异，也是系统限制下的必然妥协。

### 1. 沙箱重定向
鸿蒙严禁第三方应用访问 `/data` 或 `/system` 等全盘目录。`PathUtils.init(ctx)` 会将所有 API 传入的相对路径（如 `/Movies/`），自动重定向拼接至鸿蒙应用沙箱的绝对路径（`/data/storage/el2/base/haps/entry/files/Movies/`）。

### 2. 路径穿越防御 (Directory Traversal)
为了防范恶意攻击者请求 `/../../../etc/passwd` 窃取隐私，在 `PathUtils.resolve()` 中加入了严格的正则校验：
- 任何包含 `..` 的字符串，直接判定为非法，返回 `null`。
- 利用 `startsWith()` 确保最终解析出的绝对路径，必须仍然以沙箱根目录开头。彻底封死了跨目录访问的漏洞。

---

## 六、 混合广告分发引擎 (AdManager.ets)

项目在底层抽象了 `AdProvider` 接口，实现了两种广告分发逻辑：
1. **LocalProvider**：读取 `rawfile/ad.json`，渲染本地配置的图片或文本，适用于自建素材。
2. **PetalProvider**：返回 `adSlotId` 与 `adType`，交由鸿蒙客户端底层的 `@kit.AdsKit` (`AdComponent`) 去实时拉取华为官方广告。
Web 端在渲染时，如果检测到是 `petal` 类型的广告，会自动隐藏（因为纯网页无法渲染 Petal 原生组件），从而实现各端的原生体验。

---

## 七、 数据持久化与心跳机制

- **关系型数据**：使用 `@kit.ArkData` 的 `relationalStore`，在应用启动时自动建表（`users`、`file_hashes`），实现用户鉴权与文件秒传的 Hash 记录。
- **轻量级配置**：使用 `preferences` 存取端口、密码开关、LocalSend PIN 码等高频读写的小数据。
- **秒传心跳**：客户端在上传前，先计算本地文件的 MD5（或首尾切片 Hash），请求 `/api/upload/check`，如果服务端返回 `SECONDS_UPLOAD`，则直接跳过上传，极大提升相册备份速度。

---

## 八、 AI 驱动的工程化落地 (AI Engineering)

本项目深刻践行了“人类提需求，AI 写代码”的极限开发模式。
- 整个手写 HTTP 状态机、FTP 数据通道解析、Android 版遗留的复杂 Bug 修复，均为 AI 直接生成。
- 人类开发者（我）的主要工作是：编写清晰的 Prompt -> 复制代码到 DevEco Studio -> 编译查错 -> 真机安装测试 -> 将报错日志（如 `type mismatch`、`Promise uncaught`）喂给 AI -> 循环迭代。
- 这套架构能够稳定运行的背后，是无数次与 AI 的上下文死磕，以及根目录下那一个个用于热修复的 `fix_nas.py` 脚本。