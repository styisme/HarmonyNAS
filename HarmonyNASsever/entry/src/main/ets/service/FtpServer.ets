import { socket } from '@kit.NetworkKit';
import { fileIo } from '@kit.CoreFileKit';
import { util } from '@kit.ArkTS';
import { AuthManager } from '../manager/AuthManager';
import { PathUtils } from '../utils/PathUtils';
import { LogManager } from '../manager/LogManager';
import { concatUint8 } from '../utils/HttpUtils';

export class FtpServer {
  private server: socket.TCPSocketServer;
  private port: number;
  private clients: socket.TCPSocketConnection[] = [];
  private dataServers: socket.TCPSocketServer[] = [];
  private pasvBase = 30000;
  private pasvNext = 30000;

  constructor(port: number) {
    this.port = port;
    this.server = socket.constructTCPSocketServerInstance();
  }

  async start(): Promise<void> {
    await this.server.listen({ address: '0.0.0.0', port: this.port, family: 1 });
    this.server.on('connect', (c: socket.TCPSocketConnection) => {
      this.clients.push(c);
      new FtpSession(c, this).run();
    });
    LogManager.add('FTP', `监听 0.0.0.0:${this.port}`);
  }

  allocPasvPort(): number {
    const p = this.pasvNext;
    this.pasvNext = this.pasvNext >= 30100 ? this.pasvBase : this.pasvNext + 1;
    return p;
  }

  registerDataServer(s: socket.TCPSocketServer): void {
    this.dataServers.push(s);
  }

  stop(): void {
    try { this.server.off('connect'); this.server.close(); } catch (_) {}
    for (const s of this.dataServers) { try { s.close(); } catch (_) {} }
    this.dataServers = [];
    for (const c of this.clients) { try { c.close(); } catch (_) {} }
    this.clients = [];
  }
}

class FtpSession {
  private control: socket.TCPSocketConnection;
  private parent: FtpServer;
  private cwd: string = '/';
  private user: string = '';
  private authed: boolean = false;
  private renameFrom: string = '';
  private dataServer: socket.TCPSocketServer | null = null;
  private dataPort: number = 0;
  private buffer: string = '';

  constructor(control: socket.TCPSocketConnection, parent: FtpServer) {
    this.control = control;
    this.parent = parent;
  }

  run(): void {
    this.reply('220 Harmony NAS FTP Server Ready');
    this.control.on('message', async (info: socket.SocketMessageInfo) => {
      try {
        this.buffer += new TextDecoder().decode(new Uint8Array(info.message));
        let nl: number;
        while ((nl = this.buffer.indexOf('\r\n')) >= 0) {
          const line = this.buffer.substring(0, nl);
          this.buffer = this.buffer.substring(nl + 2);
          await this.handleLine(line);
        }
      } catch (e) {
        LogManager.add('FTP', '会话异常: ' + (e as Error).message);
      }
    });
    this.control.on('close', () => {
      try { this.dataServer?.close(); } catch (_) {}
    });
  }

  private reply(line: string): void {
    try { this.control.send({ data: new TextEncoder().encode(line + '\r\n').buffer }); }
    catch (_) {}
  }

  private async handleLine(line: string): Promise<void> {
    const sp = line.indexOf(' ');
    const cmd = (sp < 0 ? line : line.substring(0, sp)).toUpperCase();
    const arg = sp < 0 ? '' : line.substring(sp + 1);

    if (cmd === 'USER') { this.user = arg; this.reply('331 Password required'); return; }
    if (cmd === 'PASS') {
      const b64 = new util.Base64Helper().encodeToStringSync(
        new TextEncoder().encode(`${this.user}:${arg}`));
      if (AuthManager.verify('Basic ' + b64)) {
        this.authed = true; this.reply('230 Login successful');
      } else this.reply('530 Login incorrect');
      return;
    }
    if (cmd === 'SYST') { this.reply('215 UNIX Type: L8'); return; }
    if (cmd === 'FEAT') {
      this.reply('211-Features:\r\n SIZE\r\n MDTM\r\n UTF8\r\n211 End'); return;
    }
    if (cmd === 'OPTS') { this.reply('200 OK'); return; }
    if (cmd === 'TYPE') { this.reply('200 Type set to ' + arg); return; }

    if (!this.authed && cmd !== 'QUIT') {
      this.reply('530 Not logged in'); return;
    }

    if (cmd === 'PWD' || cmd === 'XPWD') {
      this.reply(`257 "${this.cwd}" is current directory`); return;
    }
    if (cmd === 'CWD') {
      const abs = PathUtils.resolve(this.joinPath(this.cwd, arg));
      if (abs && PathUtils.isDir(abs)) {
        this.cwd = PathUtils.vpath(abs);
        this.reply('250 Directory changed');
      } else this.reply('550 Directory not found');
      return;
    }
    if (cmd === 'CDUP') {
      const parts = this.cwd.replace(/\/$/, '').split('/');
      parts.pop();
      this.cwd = parts.join('/') || '/';
      this.reply('250 OK');
      return;
    }
    if (cmd === 'PASV') {
      await this.enterPassive();
      return;
    }
    if (cmd === 'LIST' || cmd === 'NLST') {
      await this.sendList(arg); return;
    }
    if (cmd === 'RETR') { await this.sendFile(arg); return; }
    if (cmd === 'STOR') { await this.receiveFile(arg); return; }
    if (cmd === 'DELE') {
      const abs = PathUtils.resolve(this.joinPath(this.cwd, arg));
      if (abs && PathUtils.exists(abs)) {
        fileIo.unlinkSync(abs); this.reply('250 Deleted');
      } else this.reply('550 Delete failed');
      return;
    }
    if (cmd === 'MKD' || cmd === 'XMKD') {
      const abs = PathUtils.resolve(this.joinPath(this.cwd, arg));
      if (abs) { fileIo.mkdirSync(abs, true); this.reply('257 Created'); }
      else this.reply('550 Create failed');
      return;
    }
    if (cmd === 'RMD' || cmd === 'XRMD') {
      const abs = PathUtils.resolve(this.joinPath(this.cwd, arg));
      if (abs && PathUtils.isDir(abs)) {
        fileIo.rmdirSync(abs); this.reply('250 Removed');
      } else this.reply('550 Remove failed');
      return;
    }
    if (cmd === 'RNFR') {
      const abs = PathUtils.resolve(this.joinPath(this.cwd, arg));
      if (abs && PathUtils.exists(abs)) {
        this.renameFrom = abs;
        this.reply('350 Ready');
      } else this.reply('550 Not found');
      return;
    }
    if (cmd === 'RNTO') {
      if (!this.renameFrom) { this.reply('503 RNFR required'); return; }
      const to = PathUtils.resolve(this.joinPath(this.cwd, arg));
      if (to) { fileIo.renameSync(this.renameFrom, to); this.reply('250 Renamed'); }
      else this.reply('550 Rename failed');
      this.renameFrom = '';
      return;
    }
    if (cmd === 'SIZE') {
      const abs = PathUtils.resolve(this.joinPath(this.cwd, arg));
      if (abs && PathUtils.exists(abs)) this.reply(`213 ${PathUtils.size(abs)}`);
      else this.reply('550 Not found');
      return;
    }
    if (cmd === 'QUIT') { this.reply('221 Goodbye'); this.control.close(); return; }

    this.reply('502 Command not implemented: ' + cmd);
  }

  private joinPath(base: string, arg: string): string {
    if (!arg) return base;
    if (arg.startsWith('/')) return arg;
    return (base.endsWith('/') ? base : base + '/') + arg;
  }

  private async enterPassive(): Promise<void> {
    try { this.dataServer?.close(); } catch (_) {}
    this.dataServer = socket.constructTCPSocketServerInstance();
    this.parent.registerDataServer(this.dataServer);
    this.dataPort = this.parent.allocPasvPort();
    try {
      await this.dataServer.listen({ address: '0.0.0.0', port: this.dataPort, family: 1 });
      const p1 = this.dataPort >> 8;
      const p2 = this.dataPort & 255;
      this.reply(`227 Entering Passive Mode (127,0,0,1,${p1},${p2})`);
    } catch (e) {
      this.reply('425 Can\'t open data connection');
      LogManager.add('FTP', 'PASV 失败: ' + (e as Error).message);
    }
  }

  private async sendList(arg: string): Promise<void> {
    if (!this.dataServer) { this.reply('425 Use PASV first'); return; }
    const abs = PathUtils.resolve(this.joinPath(this.cwd, arg));
    if (!abs) { this.reply('550 Not found'); return; }
    let entries: string[] = [];
    try {
      const names = PathUtils.isDir(abs)
        ? fileIo.listFileSync(abs)
        : [abs.substring(abs.lastIndexOf('/') + 1)];
      for (const n of names) {
        const p = PathUtils.isDir(abs)
          ? abs + (abs.endsWith('/') ? '' : '/') + n
          : abs;
        const st = fileIo.statSync(p);
        entries.push(`${st.isDirectory() ? 'drwxr-xr-x' : '-rw-r--r--'} 1 ftp ftp ${st.size} ${n}`);
      }
    } catch (_) { entries = []; }

    const payload = new TextEncoder().encode(entries.join('\r\n') + '\r\n');
    this.reply('150 Opening data connection');
    await this.sendAndClose(payload);
    this.reply('226 Transfer complete');
  }

  private async sendFile(arg: string): Promise<void> {
    if (!this.dataServer) { this.reply('425 Use PASV first'); return; }
    const abs = PathUtils.resolve(this.joinPath(this.cwd, arg));
    if (!abs || !PathUtils.exists(abs) || PathUtils.isDir(abs)) {
      this.reply('550 File not found'); return;
    }
    this.reply('150 Opening data connection');
    try {
      const size = PathUtils.size(abs);
      const fd = fileIo.openSync(abs, fileIo.OpenMode.READ_ONLY);
      const CHUNK = 64 * 1024;
      const buf = new ArrayBuffer(CHUNK);
      let offset = 0;
      const conn = await this.acceptData();
      while (offset < size) {
        const n = fileIo.readSync(fd, buf, { offset, length: Math.min(CHUNK, size - offset) });
        if (n <= 0) break;
        await conn.send({ data: buf.slice(0, n) });
        offset += n;
      }
      fileIo.closeSync(fd);
      conn.close();
      this.reply('226 Transfer complete');
    } catch (_) { this.reply('426 Transfer aborted'); }
    this.cleanupData();
  }

  private async receiveFile(arg: string): Promise<void> {
    if (!this.dataServer) { this.reply('425 Use PASV first'); return; }
    const abs = PathUtils.resolve(this.joinPath(this.cwd, arg));
    if (!abs) { this.reply('550 Access denied'); return; }
    const parent = abs.substring(0, abs.lastIndexOf('/'));
    if (parent && !PathUtils.exists(parent)) fileIo.mkdirSync(parent, true);

    this.reply('150 Ready');
    try {
      const conn = await this.acceptData();
      const f = fileIo.openSync(abs,
        fileIo.OpenMode.CREATE | fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.TRUNC);
      await new Promise<void>((resolve) => {
        conn.on('message', (m: socket.SocketMessageInfo) => {
          try { fileIo.writeSync(f.fd, new Uint8Array(m.message)); } catch (_) {}
        });
        conn.on('close', () => resolve());
      });
      fileIo.closeSync(f);
      this.reply('226 Transfer complete');
    } catch (_) { this.reply('426 Transfer aborted'); }
    this.cleanupData();
  }

  private acceptData(): Promise<socket.TCPSocketConnection> {
    return new Promise<socket.TCPSocketConnection>((resolve, reject) => {
      if (!this.dataServer) { reject(new Error('no data server')); return; }
      let resolved = false;
      this.dataServer.on('connect', (conn: socket.TCPSocketConnection) => {
        if (!resolved) { resolved = true; resolve(conn); }
      });
      setTimeout(() => { if (!resolved) { resolved = true; reject(new Error('timeout')); } }, 30000);
    });
  }

  private async sendAndClose(payload: Uint8Array): Promise<void> {
    try {
      const conn = await this.acceptData();
      await conn.send({ data: payload.buffer });
      conn.close();
    } catch (_) {}
    this.cleanupData();
  }

  private cleanupData(): void {
    try { this.dataServer?.close(); } catch (_) {}
    this.dataServer = null;
  }
}
