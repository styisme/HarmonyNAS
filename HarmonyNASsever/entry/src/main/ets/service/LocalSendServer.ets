import { socket } from '@kit.NetworkKit';
import { fileIo } from '@kit.CoreFileKit';
import { SettingsManager } from '../manager/SettingsManager';
import { LogManager } from '../manager/LogManager';
import { PathUtils } from '../utils/PathUtils';
import { concatUint8, findHeaderEnd, parseHeaders } from '../utils/HttpUtils';

interface LsSession {
  sessionId: string;
  lastActive: number;
  tokens: Map<string, string>;
  names: Map<string, string>;
}

export class LocalSendServer {
  private server: socket.TCPSocketServer;
  private port: number;
  private sessions: Map<string, LsSession> = new Map();
  private clients: socket.TCPSocketConnection[] = [];

  constructor(port: number) {
    this.port = port;
    this.server = socket.constructTCPSocketServerInstance();
  }

  async start(): Promise<void> {
    await this.server.listen({ address: '0.0.0.0', port: this.port, family: 1 });
    this.server.on('connect', (c: socket.TCPSocketConnection) => {
      this.clients.push(c);
      this.handle(c);
    });
    LogManager.add('LocalSend', `监听 0.0.0.0:${this.port}`);
    setInterval(() => this.cleanup(), 60 * 1000);
  }

  private cleanup(): void {
    const now = Date.now();
    const expired: string[] = [];
    this.sessions.forEach((s, k) => {
      if (now - s.lastActive > 5 * 60 * 1000) expired.push(k);
    });
    for (const k of expired) this.sessions.delete(k);
  }

  private handle(client: socket.TCPSocketConnection): void {
    let buffer = new Uint8Array(0);
    let parsed: boolean = false;
    let method = '';
    let uri = '';
    let headers: Record<string, string> = {};
    let contentLength = 0;
    let headerEnd = -1;

    client.on('close', () => {
      const i = this.clients.indexOf(client);
      if (i >= 0) this.clients.splice(i, 1);
    });

    client.on('message', async (info: socket.SocketMessageInfo) => {
      try {
        buffer = concatUint8(buffer, new Uint8Array(info.message));
        if (!parsed) {
          headerEnd = findHeaderEnd(buffer);
          if (headerEnd < 0) return;
          const raw = new TextDecoder().decode(buffer.subarray(0, headerEnd));
          const req = parseHeaders(raw);
          method = req.method; uri = req.uri; headers = req.headers;
          contentLength = parseInt(headers['content-length'] ?? '0');
          parsed = true;
        }
        const bodyStart = headerEnd + 4;
        if (buffer.length - bodyStart < contentLength) return;
        const body = buffer.slice(bodyStart, bodyStart + contentLength).buffer;
        await this.dispatch(client, method, uri, headers, body);
        client.close();
      } catch (e) {
        LogManager.add('LocalSend', '异常: ' + (e as Error).message);
        try { client.close(); } catch (_) {}
      }
    });
  }

  private async dispatch(client: socket.TCPSocketConnection,
                         method: string, uri: string,
                         headers: Record<string, string>,
                         body: ArrayBuffer): Promise<void> {
    if (uri === '/api/localsend/v2/register' && method === 'POST') {
      const info = JSON.stringify({
        alias: SettingsManager.getDeviceAlias(),
        version: '2.2',
        deviceModel: 'HarmonyOS',
        deviceType: 'desktop',
        fingerprint: SettingsManager.getFingerprint(),
        port: this.port,
        protocol: 'http',
        download: false
      });
      await this.reply(client, 200, info);
      return;
    }

    if (uri === '/api/localsend/v2/prepare-upload' && method === 'POST') {
      let json: Record<string, Object> = {};
      try { json = JSON.parse(new TextDecoder().decode(new Uint8Array(body))); } catch (_) {}
      const pin = String(json['pin'] ?? '');
      if (pin !== SettingsManager.getLsPin()) {
        await this.replyWithHeaders(client, 401, 'PIN Required', { 'X-LocalSend-Pin': 'true' });
        return;
      }
      const sessionId = Math.random().toString(36).substring(2, 10);
      const s: LsSession = {
        sessionId, lastActive: Date.now(),
        tokens: new Map(), names: new Map()
      };
      const filesObj = json['files'] as Record<string, { fileName?: string }> | undefined;
      const resFiles: Record<string, string> = {};
      if (filesObj) {
        for (const k of Object.keys(filesObj)) {
          const token = Math.random().toString(36).substring(2, 12);
          s.tokens.set(k, token);
          s.names.set(k, filesObj[k].fileName ?? ('LS_' + k));
          resFiles[k] = token;
        }
      }
      this.sessions.set(sessionId, s);
      const res = JSON.stringify({ sessionId, files: resFiles });
      await this.reply(client, 200, res);
      return;
    }

    if (uri === '/api/localsend/v2/upload' && method === 'POST') {
      const u = new URL(uri, 'http://x');
      const sid = u.searchParams.get('sessionId') ?? '';
      const fid = u.searchParams.get('fileId') ?? '';
      const token = u.searchParams.get('token') ?? '';
      const s = this.sessions.get(sid);
      if (!s || !token || s.tokens.get(fid) !== token) {
        await this.reply(client, 401, 'Invalid Token');
        return;
      }
      s.lastActive = Date.now();
      const dir = PathUtils.rootDir + '/Download/LocalSend';
      if (!PathUtils.exists(dir)) fileIo.mkdirSync(dir, true);
      const fileName = s.names.get(fid) ?? ('LS_' + Date.now());
      const dest = dir + '/' + fileName;
      const f = fileIo.openSync(dest,
        fileIo.OpenMode.CREATE | fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.TRUNC);
      fileIo.writeSync(f.fd, body);
      fileIo.closeSync(f);
      LogManager.add('LocalSend', '收到文件: ' + fileName);
      await this.reply(client, 200, 'OK');
      return;
    }

    if (uri.startsWith('/api/localsend/v2/cancel')) {
      const u = new URL(uri, 'http://x');
      const sid = u.searchParams.get('sessionId') ?? '';
      if (sid) this.sessions.delete(sid);
      await this.reply(client, 200, 'Cancelled');
      return;
    }

    await this.reply(client, 404, 'Not Found');
  }

  private async reply(client: socket.TCPSocketConnection, code: number, body: string): Promise<void> {
    await this.replyWithHeaders(client, code, body, {});
  }

  private async replyWithHeaders(client: socket.TCPSocketConnection, code: number,
                                 body: string, extra: Record<string, string>): Promise<void> {
    const b = new TextEncoder().encode(body);
    const statusText = code === 200 ? 'OK' : (code === 401 ? 'Unauthorized' : (code === 404 ? 'Not Found' : 'OK'));
    let h = `HTTP/1.1 ${code} ${statusText}\r\nContent-Type: application/json; charset=utf-8\r\nContent-Length: ${b.length}\r\nConnection: close\r\n`;
    for (const k of Object.keys(extra)) h += `${k}: ${extra[k]}\r\n`;
    h += '\r\n';
    const hb = new TextEncoder().encode(h);
    await client.send({ data: concatUint8(hb, b).buffer });
  }

  stop(): void {
    try { this.server.off('connect'); this.server.close(); } catch (_) {}
    for (const c of this.clients) { try { c.close(); } catch (_) {} }
    this.clients = [];
  }
}
