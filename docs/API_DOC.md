# HarmonyNAS 开发者 API 接口规范

本项目（HarmonyNAS）的 Web 网页端、鸿蒙客户端（手机/平板/2in1/TV/Watch）均通过局域网与运行在鸿蒙系统上的服务端进行通信。

与 Android 旧版本不同，鸿蒙版本去除了基于 Root 的 WebSocket 屏幕推流远控（8082端口），将核心聚焦于 **极致的纯 Socket 协议实现（HTTP/WebDAV/FTP/LocalSend）** 与 **高安全性的沙箱文件流转**。

以下是完整的接口规范说明。

---

## 📡 基础约定

- **Base URL**：`http://<局域网IP>:8080` （端口可在服务端驾驶舱修改）
- **默认端口分配**：
  - `8080`：HTTP JSON API / Web 网页端
  - `8081`：WebDAV 协议
  - `2121`：FTP 协议
  - `53317`：LocalSend 接收服务（UDP + HTTP）
- **Content-Type**：
  - 常规请求：`application/x-www-form-urlencoded` 或 `application/json`
  - 文件上传：`multipart/form-data` 或 `application/octet-stream` (PUT流)
- **鉴权方式 (Auth)**：
  - 若在服务端开启了“账号验证”，必须在所有 HTTP Header 中携带 Basic Auth。
  - Header 格式：`Authorization: Basic Base64(账号:密码)` （默认 `admin:admin`）。
  - 鉴权失败或未携带，统一返回 `401 Unauthorized`。
- **沙箱路径规则 (核心差异)**：
  - **不可访问系统全盘**。NAS 的所有 `path` 参数，均是基于鸿蒙应用沙箱 `context.filesDir` 的相对路径。
  - 虚拟根目录为 `/`。例如请求 `path=/Movies/`，服务端底层会自动映射为 `/data/storage/el2/base/haps/entry/files/Movies/`。
  - **防穿越机制**：服务端底层会对 `path` 参数进行规范化校验，任何包含 `..` 试图跳出沙箱根目录的请求，都会被直接拦截并返回 `400 Bad Request`。

---

## 📁 一、 文件管理接口 (HTTP JSON)

### 1. 获取目录列表
- **URL**: `/api/list`
- **Method**: `GET`
- **Params**:
  - `path` (String, 必填) - 目标目录的虚拟绝对路径，如 `/` 或 `/Movies/`。
- **Response**: `200 OK`
- **返回示例**:
```json
{
  "path": "/Movies/",
  "files": [
    {
      "name": "Inception.mp4",
      "dir": false,
      "size": 1024000,
      "path": "/Movies/Inception.mp4"
    },
    {
      "name": "Subs",
      "dir": true,
      "size": 0,
      "path": "/Movies/Subs"
    }
  ]
}
```
- **底层逻辑**：服务端使用 `fileIo.listFileSync` 读取目录，通过 `fileIo.statSync` 获取文件大小和类型。

### 2. 文件下载与流媒体分片
- **URL**: `/api/download`
- **Method**: `GET`
- **Params**:
  - `path` (String, 必填) - 文件的绝对路径。
- **Headers**: 可携带 `Range: bytes=0-1024`。
- **Response**:
  - 若携带 Range，返回 `206 Partial Content`，并带有 `Content-Range` 头。
  - 若未携带，返回 `200 OK`，并带有 `Content-Disposition` 触发浏览器下载。
- **底层逻辑**：服务端使用 `TCPSocketConnection` 流式读取。打开文件后，利用 `fileIo.readSync` 按 64KB 分块循环读取并发送，**绝不将整个视频文件读入内存**，彻底杜绝 OOM。

### 3. 表单多文件上传 (Web端使用)
- **URL**: `/api/upload`
- **Method**: `POST`
- **Body**: `multipart/form-data` 格式。
  - 需包含 `path` 字段（目标目录）。
  - 一个或多个 `file` 字段。
- **Response**: `200 OK`，返回字符串 `OK: filename.ext`。
- **底层逻辑**：服务端手写了 Multipart 边界解析器，将二进制 Body 按 Boundary 切分，提取 Header 中的 filename，并在沙箱内创建文件写入。

### 4. 客户端流式 PUT 上传 (鸿蒙客户端使用)
- **URL**: `/*` (任意文件路径，如 `/Movies/new.mp4`)
- **Method**: `PUT`
- **Body**: 纯二进制流 (`application/octet-stream`)。
- **注意**：客户端必须携带准确的 `Content-Length`。
- **Response**: `200 OK`。
- **底层逻辑**：服务端直接读取 Request Body 并落盘。这是跨端大文件上传（如相册备份）性能最高的方案。

### 5. 获取文本预览
- **URL**: `/api/preview`
- **Method**: `GET`
- **Params**: `path` (String, 必填)
- **Response**: `200 OK`，返回纯文本内容。
- **限制**：文件大小限制在 2MB 以内，超出返回 `400 File too large`。

### 6. 新建文件夹
- **URL**: `/api/mkdir`
- **Method**: `POST`
- **Body**: `path=/当前目录&name=新目录名`
- **Response**: `200 OK`

### 7. 重命名
- **URL**: `/api/rename`
- **Method**: `POST`
- **Body**: `path=/旧路径&newName=新名字`
- **Response**: `200 OK`

### 8. 递归删除
- **URL**: `/api/delete`
- **Method**: `POST`
- **Body**: `path=/目标路径`
- **Response**: `200 OK`
- **安全防护**：底层调用 `fileIo.rmdirSync`（该 API 原生支持递归删除）。如果 `path` 为 `/`（根目录），服务端将直接拒绝操作（返回 `400 Bad`）。

### 9. 在线保存文本
- **URL**: `/api/save`
- **Method**: `POST`
- **Body**: `path=/文件路径&content=新的文件内容`
- **Response**: `200 OK`

### 10. 在线解压 ZIP (鸿蒙原生引擎)
- **URL**: `/api/unzip`
- **Method**: `POST`
- **Body**: `path=/目标zip文件路径.zip`
- **Response**: `200 OK` (解压成功) / `500 Unzip failed` (解压异常)
- **底层逻辑**：抛弃了手写压缩包解析，直接调用鸿蒙系统原生的 `@kit.BasicServicesKit` 中的 `zlib.decompressFile`，拥有极高的解压性能与安全边界。

### 11. 生成免密分享链接
- **URL**: `/api/share`
- **Method**: `POST`
- **Body**: `path=/文件路径`
- **Response**: `200 OK`，返回 8 位随机 Token 字符串（如 `abcd1234`）。
- **访问分享**：外部用户通过 `GET /share/{token}` 即可免密直接下载该文件，无需 Auth 拦截。

---

## 🔍 二、 搜索与工具接口

### 1. 全局递归搜索
- **URL**: `/api/search`
- **Method**: `GET`
- **Params**: `q` (String, 必填) - 搜索关键字。
- **Response**: `200 OK`，返回包含 `name`, `path`, `dir`, `size` 等属性的 JSON 数组。
- **底层逻辑**：从沙箱根目录开始递归遍历，为了防止过深导致主线程卡死，限制了最大深度为 6 层，且最多返回 500 条结果。

### 2. 局域网剪贴板
- **获取剪贴板**: `GET /api/clipboard` -> 返回纯文本内容。
- **设置剪贴板**: `POST /api/clipboard`，Body: `content=要同步的文字`。
- **底层逻辑**：内容暂存于服务端内存中的全局变量（不落盘），重启服务即清空。

---

## ⚙️ 三、 系统与控制台接口

### 1. 获取服务端状态
- **URL**: `/api/status`
- **Method**: `GET`
- **Response**:
```json
{
  "lowPower": false,
  "clipboardEnabled": true,
  "globalMode": false
}
```
*(注：由于鸿蒙沙箱机制，`globalMode` 永远返回 `false`)*

### 2. 获取/保存系统配置
- **URL**: `/api/settings`
- **Method**: `GET` / `POST`
- **GET Response**:
```json
{
  "alias": "My Harmony NAS",
  "webPort": 8080,
  "davPort": 8081,
  "ftpPort": 2121,
  "webdav": true,
  "ftp": true,
  "dlna": false,
  "clipboard": true,
  "adsEnabled": true
}
```
- **POST Body**: 提交上述字段的键值对即可覆盖（`Content-Type: application/x-www-form-urlencoded`）。

### 3. 修改管理员密码
- **URL**: `/api/password`
- **Method**: `POST`
- **Body**: `password=新密码`
- **Response**: `200 OK`
- **底层逻辑**：通过 `relationalStore` 数据库执行 `UPDATE users SET password=...`。

### 4. 广告配置下发
- **URL**: `/api/ads`
- **Method**: `GET`
- **Params**: `slot=fileListBottom&count=1`
- **Response**:
```json
{
  "enabled": true,
  "refreshIntervalSec": 300,
  "ads": [
    {
      "id": "banner-001",
      "type": "image",
      "title": "HarmonyOS 生态",
      "imageUrl": "/ads/banner.png",
      "targetUrl": "https://developer.huawei.com",
      "adSlotId": "" 
    }
  ]
}
```
*(注：如果是接入 Petal Ads，`imageUrl` 为空，返回 `adSlotId`，由客户端渲染原生 AdComponent)*

### 5. 广告曝光/点击埋点
- **URL**: `/api/ads/impression` 或 `/api/ads/click`
- **Method**: `POST`
- **Body**: `adId=xxx&slot=xxx`

---

## 📂 四、 原生 WebDAV 协议规范 (8081端口)

本项目的 WebDAV 服务并非使用第三方库，而是基于 `TCPSocketServer` **纯手写解析 HTTP 报文**实现的。

### 1. 鉴权机制
WebDAV 每次请求均会校验 `Authorization: Basic Base64(username:password)`。如果没有，返回 `401 Unauthorized`，并在 Header 中加入 `WWW-Authenticate: Basic realm="Harmony NAS WebDAV"`。

### 2. PROPFIND (获取文件属性)
- **Method**: `PROPFIND`
- **Headers**: 
  - `Depth: 0` (只看当前文件)
  - `Depth: 1` (看当前目录及子文件)
- **Response**: `207 Multi-Status`
- **返回内容**:
```xml
<?xml version="1.0" encoding="utf-8"?>
<D:multistatus xmlns:D="DAV:">
  <D:response>
    <D:href>/Movies/</D:href>
    <D:propstat>
      <D:prop>
        <D:displayname>Movies</D:displayname>
        <D:getcontentlength>0</D:getcontentlength>
        <D:resourcetype><D:collection/></D:resourcetype>
      </D:prop>
      <D:status>HTTP/1.1 200 OK</D:status>
    </D:propstat>
  </D:response>
</D:multistatus>
```

### 3. PUT (上传/覆盖)
- **Method**: `PUT`
- **Header**: `Content-Length: 10240` (必须准确)
- **Body**: 二进制流
- **Response**: `201 Created` (新文件) / `204 No Content` (覆盖旧文件)

### 4. DELETE (删除)
- **Method**: `DELETE`
- **Response**: `204 No Content` (成功) / `404 Not Found` (文件不存在)
- **注意**：手写实现中，删除目录会调用系统的递归删除。

### 5. MKCOL (建目录)
- **Method**: `MKCOL`
- **Response**: `201 Created` / `405 Method Not Allowed` (已存在)

---

## ⌨️ 五、 原生 FTP 协议规范 (2121端口)

同样采用纯 Socket 手写实现，兼容 Windows 资源管理器与电视盒子。

### 1. 控制连接生命周期
- 客户端连接后，服务端主动发送：`220 Harmony NAS FTP Server Ready`
- 客户端发送 `USER admin` -> 服务端回：`331 Password required`
- 客户端发送 `PASS admin` -> 服务端验证 Basic Auth -> 回：`230 Login successful`

### 2. 被动模式 (PASV) 核心逻辑
为了绕过客户端防火墙，FTP 必须使用被动模式：
1. 客户端发送 `PASV`。
2. 服务端动态开启一个临时端口（如 30001），并回复：`227 Entering Passive Mode (127,0,0,1,117,49)`。（117*256+49 = 30001）。
3. 客户端连接 30001 端口，进行数据（文件）传输。

### 3. 支持的核心指令表
- `PWD` / `CWD` / `CDUP`：目录导航。
- `LIST`：返回 Unix 风格的文件列表字符串（如 `drwxr-xr-x 1 ftp ftp 0 date name`）。
- `RETR`：下载文件（数据流）。
- `STOR`：上传文件（数据流）。
- `DELE` / `MKD` / `RMD`：删除、建目录、删目录。
- `RNFR` + `RNTO`：重命名（分两步发送）。
- `SIZE`：获取文件大小。

---

## 📡 六、 LocalSend 协议栈实现 (53317端口)

无需安装 LocalSend 客户端，系统底层直接实现了标准协议，支持跨平台免登录传输。

### 1. 组播发现
- **UDP 监听**：监听 `224.0.0.167:53317`。
- **响应逻辑**：当收到包含 `"fingerprint"` 的 JSON 组播报文时，服务端会单播回复自身的 JSON 信息（包含 `alias`, `port`, `fingerprint` 等）。

### 2. HTTP 接收流程
- **准备上传 (`/api/localsend/v2/prepare-upload`)**：
  - Body 包含客户端想要发送的文件元数据。
  - 服务端校验 Body 里的 `pin` 是否与设置一致。不一致返回 `401`。
  - 一致则生成 SessionId，为每个文件分配 Token，返回给客户端。
- **正式上传 (`/api/localsend/v2/upload`)**：
  - Query 参数携带 `sessionId`, `fileId`, `token`。
  - 服务端校验 Token 合法后，将文件二进制流写入 `/Download/LocalSend/` 目录。
  - 同名文件自动重命名避让（如 `video(1).mp4`）。

---

## 🚨 附录：HTTP 状态码字典

| 状态码 | 含义 | 触发场景 |
|---|---|---|
| `200` | OK | 常规成功 |
| `201` | Created | WebDAV / FTP 创建成功 |
| `206` | Partial Content | 触发 Range 流媒体拖动播放 |
| `400` | Bad Request | 缺少 path 参数 / 路径穿越 / 非法重命名 |
| `401` | Unauthorized | 账号密码错误 / 未携带 Basic Auth |
| `403` | Forbidden | 权限不足 / 尝试操作沙箱根目录 |
| `404` | Not Found | 文件不存在 / 分享 Token 过期 |
| `500` | Internal Server Error | 沙箱磁盘已满 / 解压引擎崩溃 |