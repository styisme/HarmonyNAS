
# AI 生成声明

本项目（HarmonyNAS 鸿蒙原生版）在移植与开发过程中，深度使用了大型语言模型（LLM）辅助生成代码。为了开源协作的透明度，特此详细披露 AI 的参与程度。

**核心声明：本项目 99% 以上的核心代码（包括 ArkTS、HTML、CSS、Python 脚本等）均由 AI 直接输出，人类开发者在此过程中主要负责产品定义、真机编译与测试反馈。**

## AI 参与的具体部分

- **服务端核心 (Server Core - ArkTS)**：
  - `HttpServer.ets`：纯手写基于 `TCPSocketServer` 的 HTTP/1.1 报文解析、状态机与 Range 分片流式发送。
  - `NasApiRouter.ets`：全量路由分发，包含文件列表、文本读写、ZIP 原生解压、跨端剪贴板等。
  - `WebDavServer.ets` / `FtpServer.ets`：纯 Socket 报文级手写协议栈，支持 WebDAV 的 `PROPFIND` 与 FTP 的 `PASV` 被动模式。
  - `HttpUtils.ets`：手写 Multipart 边界解析器与 JSON/Form 表单解析器。

- **鸿蒙客户端 (Client - ArkTS)**：
  - `DeviceAdapter.ets`：多设备形态决策引擎与响应式断点计算。
  - `AdaptiveScaffold.ets`：一套代码适配手机（底部Tab）、平板（双栏）、TV（焦点网格）的外壳布局。
  - `NasClient.ets`：基于 `@kit.NetworkKit` 的 HTTP 请求封装与大文件流式 PUT 上传。
  - `BackupService.ets`：基于 `photoAccessHelper` 的相册增量扫描与秒传比对。

- **Web 网页端 (Web - HTML/JS/CSS)**：
  - `index.html`：全量 UI 编写，5 大广告位接入，401 全局 Fetch 拦截器，流媒体预览引擎重构。

- **工具链与 DevOps**：
  - `scaffold.py` / `fix_nas.py`：Python 自动化代码生成与文件修补脚本。

## 开发者（人类）负责的核心工作

- **产品架构决策**：决定纯原生鸿蒙方案，完全拥抱沙箱；决定剥离沉重的 WebSocket 远控，聚焦安全文件流转。
- **真机编译测试**：在 DevEco Studio 中配置签名，处理 AI 生成的 ArkTS 语法在严格模式下的报错，并在鸿蒙物理设备（手机、平板、TV）上验证 TCP Socket 协议栈的连通性。
- **反馈与修正**：将报错日志（如 `type mismatch`、`Promise uncaught`）或 UI 截图反馈给 AI，由 AI 输出热修复补丁。

## 已知的局限性

1. **沙箱限制**：鸿蒙系统严禁第三方应用提权，无法实现类似 Android Root 的全盘访问。
2. **边缘场景依赖人类测试**：AI 无法真机运行，不同设备（如电视盒子与手表）的焦点滑动体验、网络并发延迟必须依靠人类反复测试。
3. **签名限制**：鸿蒙 HAP 包必须经过实名认证的证书签名，云端 CI 无法直接生成用户可直接安装的安装包，只能输出未签名源码。

## 协议

本项目遵循 MIT 协议。