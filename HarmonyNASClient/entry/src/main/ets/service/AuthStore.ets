import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { ServerConfig } from '../model/ApiTypes';
import { util } from '@kit.ArkTS';

export class AuthStore {
  private static prefs: preferences.Preferences | null = null;

  static init(ctx: common.Context): void {
    AuthStore.prefs = preferences.getPreferencesSync(ctx, { name: 'nas_client_auth' });
  }

  static save(cfg: ServerConfig): void {
    AuthStore.prefs?.putSync('cfg', JSON.stringify(cfg));
    AuthStore.prefs?.flush();
  }

  static load(): ServerConfig | null {
    const s = AuthStore.prefs?.getSync('cfg', '') as string;
    if (!s) return null;
    try { return JSON.parse(s) as ServerConfig; } catch (_) { return null; }
  }

  static clear(): void {
    AuthStore.prefs?.deleteSync('cfg');
    AuthStore.prefs?.flush();
  }

  static toBasic(cfg: ServerConfig): string {
    const raw = `${cfg.user}:${cfg.pass}`;
    const enc = new util.Base64Helper().encodeToStringSync(new TextEncoder().encode(raw));
    return 'Basic ' + enc;
  }

  static baseUrl(cfg: ServerConfig): string {
    let host = cfg.host.trim();
    if (!host.startsWith('http')) host = 'http://' + host;
    host = host.replace(/\/$/, '');
    return host.includes(':') ? host : `${host}:${cfg.port}`;
  }
}
