import { socket } from '@kit.NetworkKit';
import { fileIo } from '@kit.CoreFileKit';
import { AuthManager } from '../manager/AuthManager';
import { PathUtils } from '../utils/PathUtils';
import { LogManager } from '../manager/LogManager';
import { findHeaderEnd, concatUint8, guessMime } from '../utils/HttpUtils';

interface DavRequest {
  method: string;
  uri: string;
  headers: Record<string, string>;
  body: ArrayBuffer;
}

export class WebDavServer {
  private server: socket.TCPSocketServer;
  private port: number;
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
    LogManager.add('WebDAV', `监听 0.0.0.0:${this.port}`);
  }

  private handle(client: socket.TCPSocketConnection): void {
    let buffer = new Uint8Array(0);
    let req: DavRequest | null = null;
    let contentLength = 0;
    let headerEnd = -1;

    client.on('close', () => {
      const i = this.clients.indexOf(client);
      if (i >= 0) this.clients.splice(i, 1);
    });

    client.on('message', async (info: socket.SocketMessageInfo) => {
      try {
        buffer = concatUint8(buffer, new Uint8Array(info.message));

        if (!req) {
          headerEnd = findHeaderEnd(buffer);
          if (headerEnd < 0) return;
          const raw = new TextDecoder().decode(buffer.subarray(0, headerEnd));
          const lines = raw.split('\r\n');
          const [method, rawUri] = lines[0].split(' ');
          const uri = rawUri.split('?')[0];
          const headers: Record<string, string> = {};
          for (let i = 1; i < lines.length; i++) {
            const idx = lines[i].indexOf(':');
            if (idx > 0) {
              headers[lines[i].substring(0, idx).trim().toLowerCase()] =
                lines[i].substring(idx + 1).trim();
            }
          }
          contentLength = parseInt(headers['content-length'] ?? '0');
          req = { method, uri, headers, body: new ArrayBuffer(0) };
        }

        const bodyStart = headerEnd + 4;
        if (buffer.length - bodyStart < contentLength) return;
        req.body = buffer.slice(bodyStart, bodyStart + contentLength).buffer;

        await this.dispatch(client, req);
        client.close();
      } catch (e) {
        LogManager.add('WebDAV', '异常: ' + (e as Error).message);
        try { client.close(); } catch (_) {}
      }
    });
  }

  private async dispatch(client: socket.TCPSocketConnection, req: DavRequest): Promise<void> {
    let uri = req.uri;
    if (!uri.startsWith('/')) uri = '/' + uri;

    if (req.method !== 'OPTIONS' && !AuthManager.verify(req.headers['authorization'])) {
      await this.write(client, 401, '', { 'WWW-Authenticate': 'Basic realm="Harmony NAS WebDAV"' });
      return;
    }

    const abs = PathUtils.resolve(uri);
    if (!abs) { await this.write(client, 403, ''); return; }

    if (req.method === 'PROPFIND') {
      if (!PathUtils.exists(abs)) { await this.write(client, 404, ''); return; }
      const xml = this.buildXml(abs, uri, req.headers['depth'] === '0');
      await this.write(client, 207, xml, { 'Content-Type': 'application/xml; charset="utf-8"' });
    } else if (req.method === 'PUT') {
      const parent = abs.substring(0, abs.lastIndexOf('/'));
      if (parent && !PathUtils.exists(parent)) fileIo.mkdirSync(parent, true);
      const existed = PathUtils.exists(abs);
      const f = fileIo.openSync(abs,
        fileIo.OpenMode.CREATE | fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.TRUNC);
      fileIo.writeSync(f.fd, req.body);
      fileIo.closeSync(f);
      await this.write(client, existed ? 204 : 201, '');
    } else if (req.method === 'DELETE') {
      if (PathUtils.exists(abs)) {
        fileIo.rmdirSync(abs);
        await this.write(client, 204, '');
      } else await this.write(client, 404, '');
    } else if (req.method === 'MKCOL') {
      if (PathUtils.exists(abs)) { await this.write(client, 405, ''); return; }
      fileIo.mkdirSync(abs, true);
      await this.write(client, 201, '');
    } else if (req.method === 'GET' || req.method === 'HEAD') {
      if (!PathUtils.exists(abs) || PathUtils.isDir(abs)) {
        await this.write(client, 404, ''); return;
      }
      const size = PathUtils.size(abs);
      const head = `HTTP/1.1 200 OK\r\nContent-Length: ${size}\r\nContent-Type: ${guessMime(abs)}\r\nConnection: close\r\n\r\n`;
      await client.send({ data: new TextEncoder().encode(head).buffer });
      if (req.method === 'GET') {
        const fd = fileIo.openSync(abs, fileIo.OpenMode.READ_ONLY);
        const CHUNK = 64 * 1024;
        const buf = new ArrayBuffer(CHUNK);
        let offset = 0;
        while (offset < size) {
          const n = fileIo.readSync(fd, buf, { offset, length: Math.min(CHUNK, size - offset) });
          if (n <= 0) break;
          await client.send({ data: buf.slice(0, n) });
          offset += n;
        }
        fileIo.closeSync(fd);
      }
    } else if (req.method === 'OPTIONS') {
      await this.write(client, 200, '', {
        'DAV': '1',
        'Allow': 'OPTIONS,GET,HEAD,PUT,DELETE,PROPFIND,MKCOL'
      });
    } else {
      await this.write(client, 405, '');
    }
  }

  private buildXml(abs: string, vp: string, depth0: boolean): string {
    const lines: string[] = ['<?xml version="1.0" encoding="utf-8"?>', '<D:multistatus xmlns:D="DAV:">'];
    this.appendResp(lines, abs, vp);
    if (!depth0) {
      try {
        for (const n of fileIo.listFileSync(abs)) {
          const p = abs + (abs.endsWith('/') ? '' : '/') + n;
          this.appendResp(lines, p, (vp.endsWith('/') ? vp : vp + '/') + n);
        }
      } catch (_) {}
    }
    lines.push('</D:multistatus>');
    return lines.join('\n');
  }

  private appendResp(lines: string[], abs: string, vp: string): void {
    let st: fileIo.Stat;
    try { st = fileIo.statSync(abs); } catch (_) { return; }
    lines.push('<D:response>');
    lines.push(`<D:href>${vp}</D:href>`);
    lines.push('<D:propstat><D:prop>');
    lines.push(`<D:displayname>${abs.substring(abs.lastIndexOf('/') + 1)}</D:displayname>`);
    if (!st.isDirectory()) lines.push(`<D:getcontentlength>${st.size}</D:getcontentlength>`);
    lines.push(st.isDirectory()
      ? '<D:resourcetype><D:collection/></D:resourcetype>'
      : '<D:resourcetype/>');
    lines.push('</D:prop><D:status>HTTP/1.1 200 OK</D:status></D:propstat>');
    lines.push('</D:response>');
  }

  private async write(client: socket.TCPSocketConnection, code: number,
                      body: string, headers: Record<string, string> = {}): Promise<void> {
    const b = new TextEncoder().encode(body);
    let h = `HTTP/1.1 ${code} ${codeText(code)}\r\nContent-Length: ${b.length}\r\nConnection: close\r\n`;
    for (const k of Object.keys(headers)) h += `${k}: ${headers[k]}\r\n`;
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

function codeText(c: number): string {
  const m: Record<number, string> = {
    200: 'OK', 201: 'Created', 204: 'No Content', 207: 'Multi-Status',
    401: 'Unauthorized', 403: 'Forbidden', 404: 'Not Found', 405: 'Method Not Allowed'
  };
  return m[c] ?? 'OK';
}
