import { socket } from '@kit.NetworkKit';
import { fileIo } from '@kit.CoreFileKit';
import { HttpRequest, HttpResponse, RequestHandler } from '../model/HttpTypes';
import { LogManager } from '../manager/LogManager';
import { parseHeaders, findHeaderEnd, concatUint8 } from '../utils/HttpUtils';

const MAX_BODY = 512 * 1024 * 1024;

export class HttpServer {
  private server: socket.TCPSocketServer;
  private handler: RequestHandler;
  private port: number;
  private clients: socket.TCPSocketConnection[] = [];

  constructor(port: number, handler: RequestHandler) {
    this.port = port;
    this.handler = handler;
    this.server = socket.constructTCPSocketServerInstance();
  }

  async start(): Promise<void> {
    await this.server.listen({ address: '0.0.0.0', port: this.port, family: 1 });
    this.server.on('connect', (client: socket.TCPSocketConnection) => {
      this.clients.push(client);
      this.handleConnection(client);
    });
    LogManager.add('HTTP', `监听 0.0.0.0:${this.port}`);
  }

  private handleConnection(client: socket.TCPSocketConnection): void {
    let buffer = new Uint8Array(0);
    let req: HttpRequest | null = null;
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
          const headerStr = new TextDecoder().decode(buffer.subarray(0, headerEnd));
          req = parseHeaders(headerStr);
          contentLength = parseInt(req.headers['content-length'] ?? '0');
          if (contentLength > MAX_BODY) {
            await this.sendSimple(client, 413, 'Payload Too Large');
            client.close();
            return;
          }
        }

        const bodyStart = headerEnd + 4;
        if (buffer.length - bodyStart < contentLength) return;

        req.body = buffer.slice(bodyStart, bodyStart + contentLength).buffer;
        const resp = await this.handler(req);
        await this.writeResponse(client, resp);
        client.close();
      } catch (e) {
        LogManager.add('HTTP', '异常: ' + (e as Error).message);
        try { client.close(); } catch (_) {}
      }
    });
  }

  private async writeResponse(client: socket.TCPSocketConnection,
                              resp: HttpResponse): Promise<void> {
    if (resp.streamFile) { await this.writeStreamFile(client, resp); return; }

    const body = typeof resp.body === 'string'
      ? new TextEncoder().encode(resp.body)
      : new Uint8Array(resp.body ?? new ArrayBuffer(0));
    const head = this.buildHeader(resp, body.length);
    await client.send({ data: concatUint8(head, body).buffer });
  }

  private async writeStreamFile(client: socket.TCPSocketConnection,
                                resp: HttpResponse): Promise<void> {
    const sf = resp.streamFile!;
    const start = sf.rangeStart ?? 0;
    const end = sf.rangeEnd ?? (sf.size - 1);
    const length = end - start + 1;

    const head = this.buildHeader(resp, length, {
      'Content-Type': sf.mime,
      'Accept-Ranges': 'bytes',
      ...(sf.rangeStart !== undefined
        ? { 'Content-Range': `bytes ${start}-${end}/${sf.size}` }
        : { 'Content-Disposition':
            `attachment; filename="${encodeURIComponent(sf.name ?? 'file')}"` })
    });
    await client.send({ data: head.buffer });

    const CHUNK = 64 * 1024;
    const buf = new ArrayBuffer(CHUNK);
    let offset = start;
    while (offset <= end) {
      const n = fileIo.readSync(sf.fd, buf,
        { offset, length: Math.min(CHUNK, end - offset + 1) });
      if (n <= 0) break;
      await client.send({ data: buf.slice(0, n) });
      offset += n;
    }
  }

  private buildHeader(resp: HttpResponse, len: number,
                      extra: Record<string, string> = {}): Uint8Array {
    const lines = [`HTTP/1.1 ${resp.status} ${STATUS_TEXT[resp.status] ?? 'OK'}`];
    const headers: Record<string, string> = {
      'Content-Length': `${len}`, 'Connection': 'close',
      ...(resp.headers ?? {}), ...extra
    };
    for (const k of Object.keys(headers)) lines.push(`${k}: ${headers[k]}`);
    lines.push('', '');
    return new TextEncoder().encode(lines.join('\r\n'));
  }

  private async sendSimple(client: socket.TCPSocketConnection,
                           code: number, msg: string): Promise<void> {
    const body = new TextEncoder().encode(msg);
    const head = new TextEncoder().encode(
      `HTTP/1.1 ${code} ${STATUS_TEXT[code] ?? 'OK'}\r\nContent-Length: ${body.length}\r\nConnection: close\r\n\r\n`);
    await client.send({ data: concatUint8(head, body).buffer });
  }

  stop(): void {
    try { this.server.off('connect'); this.server.close(); } catch (_) {}
    for (const c of this.clients) { try { c.close(); } catch (_) {} }
    this.clients = [];
  }
}

const STATUS_TEXT: Record<number, string> = {
  200: 'OK', 201: 'Created', 204: 'No Content', 206: 'Partial Content', 207: 'Multi-Status',
  400: 'Bad Request', 401: 'Unauthorized', 403: 'Forbidden', 404: 'Not Found',
  405: 'Method Not Allowed', 413: 'Payload Too Large', 500: 'Internal Server Error'
};
