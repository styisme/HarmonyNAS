import { common } from '@kit.AbilityKit';
import { SettingsManager } from '../manager/SettingsManager';
import { DatabaseManager } from '../manager/DatabaseManager';
import { AuthManager } from '../manager/AuthManager';
import { AdManager } from '../manager/AdManager';
import { VersionManager } from '../manager/VersionManager';
import { LogManager } from '../manager/LogManager';
import { PathUtils } from '../utils/PathUtils';
import { HttpServer } from './HttpServer';
import { NasApiRouter } from './NasApiRouter';
import { WebDavServer } from './WebDavServer';
import { FtpServer } from './FtpServer';
import { LocalSendServer } from './LocalSendServer';
import { LocalSendDiscovery } from './LocalSendDiscovery';
import { DlnaServer } from './DlnaServer';

export class NasService {
  private static inst: NasService | null = null;
  static get(): NasService {
    if (!this.inst) this.inst = new NasService();
    return this.inst;
  }

  private http: HttpServer | null = null;
  private webdav: WebDavServer | null = null;
  private ftp: FtpServer | null = null;
  private lsServer: LocalSendServer | null = null;
  private lsDiscovery: LocalSendDiscovery | null = null;
  private dlna: DlnaServer | null = null;
  private started: boolean = false;

  async start(ctx: common.Context): Promise<void> {
    if (this.started) return;
    this.started = true;

    SettingsManager.init(ctx);
    const root = ctx.filesDir;
    PathUtils.init(root);

    await DatabaseManager.init(ctx);
    AuthManager.init();
    await VersionManager.load(ctx);
    await AdManager.load(ctx);

    LogManager.add('SYSTEM',
      `启动 HarmonyNAS ${VersionManager.get().versionName}, 根 ${root}`);
    NasApiRouter.ctx = ctx;

    const router = new NasApiRouter();
    this.http = new HttpServer(SettingsManager.getWebPort(), (r) => router.handle(r));
    try { await this.http.start(); }
    catch (e) { LogManager.add('SYSTEM', 'HTTP 启动失败: ' + (e as Error).message); }

    if (SettingsManager.isWebDavEnabled()) {
      this.webdav = new WebDavServer(SettingsManager.getWebDavPort());
      try { await this.webdav.start(); }
      catch (e) { LogManager.add('WebDAV', '启动失败: ' + (e as Error).message); this.webdav = null; }
    }

    if (SettingsManager.isFtpEnabled()) {
      this.ftp = new FtpServer(SettingsManager.getFtpPort());
      try { await this.ftp.start(); }
      catch (e) { LogManager.add('FTP', '启动失败: ' + (e as Error).message); this.ftp = null; }
    }

    if (SettingsManager.isLocalSendEnabled()) {
      this.lsServer = new LocalSendServer(53317);
      try { await this.lsServer.start(); }
      catch (e) { LogManager.add('LocalSend', '启动失败: ' + (e as Error).message); this.lsServer = null; }
      try {
        this.lsDiscovery = new LocalSendDiscovery(ctx);
        this.lsDiscovery.start();
      } catch (e) {
        LogManager.add('LocalSend', 'UDP 发现启动失败: ' + (e as Error).message);
        this.lsDiscovery = null;
      }
    }

    if (SettingsManager.isDlnaEnabled()) {
      try {
        this.dlna = new DlnaServer(ctx);
        this.dlna.start();
      } catch (e) {
        LogManager.add('DLNA', '启动失败: ' + (e as Error).message);
        this.dlna = null;
      }
    }
  }

  stop(): void {
    this.http?.stop(); this.http = null;
    this.webdav?.stop(); this.webdav = null;
    this.ftp?.stop(); this.ftp = null;
    this.lsServer?.stop(); this.lsServer = null;
    this.lsDiscovery?.stop(); this.lsDiscovery = null;
    this.dlna?.stop(); this.dlna = null;
    this.started = false;
    LogManager.add('SYSTEM', 'NAS 已停止');
  }
}
