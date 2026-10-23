# HarmonyNAS 底层架构深度解析 (Architecture)

作为首个完全基于 **HarmonyOS NEXT (API 12)** 原生重构的局域网 NAS 系统，HarmonyNAS 并没有简单地将旧版 Java 代码进行翻译，而是彻底抛弃了第三方重型容器（如 NanoHTTPD、Spring 等），完全依靠 ArkTS 的语言特性与鸿蒙系统的底层 Kit 能力，从零构建了一套**手写协议栈与沙箱自适应**架构。

本文档将深度剖析项目的底层运行原理，带你了解这套系统是如何在严格的沙箱限制下，榨干纯血鸿蒙性能的。

---

## 一、 核心容器调度与生命周期 (NasService)

服务端以 `UIAbility` 为宿主。为了在系统严苛的资源管控下存活，它并没有像传统 Android 那样采用各种“保活 Hack”，而是光明正大地利用了系统级的合法长时任务。

1. **合法保活**：在 `EntryAbility.ets` 的 `onWindowStageCreate` 中，主动向系统申请 `backgroundTaskManager.ContinuousTaskRequest`，并指定 `backgroundMode: DATA_TRANSFER`。这使得应用即便退入后台或锁屏，底层的 TCP Socket 也不会被冻结。
2. **多线程并发调度**：`NasService.ets` 作为总编排器，在初始化完毕后，会并行拉起多个核心服务，它们互不阻塞：
   - `8080` 端口：`HttpServer` (处理 Web 前端与 JSON API)
   - `8081` 端口：`WebDavServer` (处理标准网络磁盘挂载)
   - `2121` 端口：`FtpServer` (处理老旧设备与电视盒子的连接)
   - `53317` 端口：`LocalSendServer` (UDP 发现与 HTTP 接收)

---

## 二、 纯血手写 HTTP/1.1 协议栈 (HttpServer)

鸿蒙系统没有内置的 HttpServer 模块。我们基于 `@kit.NetworkKit` 的 `TCPSocketServer` 实现了一个完整的应用层状态机。

### 1. TCP 字节流的拼装与截断
底层的 Socket 是一堆无序且可能被截断的字节流。`HttpServer.ets` 内部维护了一个 `Uint8Array` 缓冲区：
- 每次收到 `on('message')` 回调，将新的 ArrayBuffer 拼接至缓冲区。
- 利用正则或字节扫描寻找 `\r\n\r\n`，精准切分 HTTP Header 和 Body。
- 解析 Header 中的 `Content-Length`，精准等待 Body 接收完毕（防止粘包），再触发路由处理。

### 2. Range 分片流式发送 (防 OOM 的核心)
当网页端拖动视频进度条时，会发送 `Range: bytes=0-1024` 请求头。
- 服务端没有使用 `fileIo.readSync` 一次性读完整个视频，而是开启了一个 `while` 循环。
- 每次从文件的特定 `offset` 读取 64KB 的 `ArrayBuffer`，立刻通过 `client.send()` 发送给前端。
- 这种方式**无论视频有多大（哪怕是 100GB），服务端的内存占用永远保持在极低的水平**，彻底杜绝了 OOM（内存溢出）崩溃。

### 3. Multipart 边界解析器
Web 端的上传采用 `multipart/form-data` 格式。我们在 `HttpUtils.ets` 中通过字符串 `split` 实现了手写的 Boundary 解析，提取二进制文件流。这种原生解析虽然代码量大，但没有任何第三方依赖，包体极小。

---

## 三、 原生协议拦截与解析 (WebDAV & FTP)

### 1. 手写 WebDAV 报文 (WebDavServer)
为了能被 Windows 资源管理器直接挂载，系统复用了 TCP 框架，在 8081 端口独立解析 XML：
- 拦截到 `PROPFIND` 指令时，服务端递归遍历沙箱目录，手动拼接符合 DAV 规范的 `<D:multistatus>` XML 树，并设置 Header `Depth: 1`。
- 拦截到 `PUT` 指令时，剥离报文头，将剩余流式写入沙箱文件。

### 2. FTP 控制流与 PASV 模式 (FtpServer)
FTP 的难点在于**控制通道与数据通道分离**：
- 客户端发送 `PASV`（被动模式）后，服务端会利用 `TCPSocketServer` 动态开启一个新的临时端口（如 30001），并通过控制通道返回 `227 Entering Passive Mode`。
- 客户端随后连接 30001 端口进行大文件传输。这种实现完美绕过了现代路由器与防火墙对主动模式的拦截。

---

## 四、 多设备自适应渲染引擎 (DeviceAdapter)

这是鸿蒙端最核心的亮点。如何用一套 ArkTS 代码，同时跑在手机、平板和电视上？答案在 `util/DeviceAdapter.ets` 中。

### 1. 断点与设备类型决策
- 监听 `mediaquery` 获取当前窗口宽度（vp）。
- 读取 `deviceInfo.deviceType` 判断设备物理形态。
- 核心决策树 `LayoutDecision` 返回对应的布局参数：
  - **Phone**：单栏布局，`showBottomTabs: true`。
  - **Tablet / 2in1**：双栏 Split 布局，左侧固定 `SideBar`，右侧内容区网格列数设为 3-5。
  - **TV**：全屏沉浸式网格，无底部导航。

### 2. 焦点系统与遥控器适配
在 TV 端，传统的鼠标/触摸事件失效。我们在 `FocusableCard.ets` 中：
- 开启 `.focusable(true)`。
- 监听 `.onFocus()` 和 `.onBlur()`，配合 `.scale({ x: 1.1, y: 1.1 })` 属性与 `.animation` 动画，实现极致的“卡片放大”效果。
- 监听 `.onKeyEvent()`，拦截遥控器的 `KEYCODE_ENTER` 或 `KEYCODE_DPAD_CENTER` 模拟确认点击。

---

## 五、 严格的安全沙箱与防穿越 (PathUtils)

### 1. 沙箱重定向
鸿蒙严禁第三方应用访问全盘。`PathUtils.init(ctx)` 会将所有 API 传入的相对路径（如 `/Movies/`），自动重定向拼接至鸿蒙应用沙箱的绝对路径（`/data/storage/el2/base/haps/entry/files/Movies/`）。

### 2. 路径穿越防御 (Directory Traversal)
为了防范恶意攻击者请求 `/../../../etc/passwd`，在 `PathUtils.resolve()` 中加入了严格的正则校验：
- 任何包含 `..` 的字符串，直接判定为非法，返回 `null`。
- 利用 `startsWith()` 确保最终解析出的绝对路径，必须仍然以沙箱根目录开头。彻底封死了跨目录访问的漏洞。

---

## 六、 混合广告分发引擎 (AdManager)

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

## 八、 核心组件生命周期与清理

在纯手写 Socket 的架构中，最容易翻车的是**句柄泄漏**。
- `HttpServer` 维护了一个 `clients: TCPSocketConnection[]` 数组，用于抵抗 GC 回收。
- 当 `on('close')` 触发时，会立刻将该 client 从数组剔除并销毁。
- 在服务停止时，遍历关闭所有客户端连接，并释放端口绑定，确保再次启动服务时不会报 `Address already in use`。

这套架构虽然在代码量上远超传统的引入第三方库的做法，但它赋予了我们在鸿蒙全场景设备上极其细腻的控制力，也为后续的 `TCPSocket` 扩展（如 H264 推流）留下了无穷的可能。