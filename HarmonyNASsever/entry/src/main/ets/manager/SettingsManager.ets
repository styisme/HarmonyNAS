import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';

export class SettingsManager {
  private static prefs: preferences.Preferences | null = null;

  static init(ctx: common.Context): void {
    SettingsManager.prefs = preferences.getPreferencesSync(ctx, { name: 'nas_settings' });
  }

  private static get<T>(k: string, d: T): T {
    return (SettingsManager.prefs?.getSync(k, d) ?? d) as T;
  }
  private static set(k: string, v: preferences.ValueType): void {
    SettingsManager.prefs?.putSync(k, v);
    SettingsManager.prefs?.flush();
  }

  static getDeviceAlias(): string { return this.get('device_alias', 'Harmony NAS'); }
  static setDeviceAlias(v: string): void { this.set('device_alias', v); }

  static getWebPort(): number { return this.get('web_port', 8080); }
  static setWebPort(p: number): void { this.set('web_port', p); }

  static getWebDavPort(): number { return this.get('webdav_port', 8081); }
  static setWebDavPort(p: number): void { this.set('webdav_port', p); }

  static getFtpPort(): number { return this.get('ftp_port', 2121); }
  static setFtpPort(p: number): void { this.set('ftp_port', p); }

  static isAuthEnabled(): boolean { return this.get('auth_enabled', true); }
  static setAuthEnabled(v: boolean): void { this.set('auth_enabled', v); }

  static isWebDavEnabled(): boolean { return this.get('webdav_enabled', true); }
  static setWebDavEnabled(v: boolean): void { this.set('webdav_enabled', v); }

  static isFtpEnabled(): boolean { return this.get('ftp_enabled', true); }
  static setFtpEnabled(v: boolean): void { this.set('ftp_enabled', v); }

  static isDlnaEnabled(): boolean { return this.get('dlna_enabled', false); }
  static setDlnaEnabled(v: boolean): void { this.set('dlna_enabled', v); }

  static isLocalSendEnabled(): boolean { return this.get('localsend_enabled', true); }
  static setLocalSendEnabled(v: boolean): void { this.set('localsend_enabled', v); }

  static isClipboardEnabled(): boolean { return this.get('clipboard_enabled', true); }
  static setClipboardEnabled(v: boolean): void { this.set('clipboard_enabled', v); }

  static isAdsEnabled(): boolean { return this.get('ads_enabled', true); }
  static setAdsEnabled(v: boolean): void { this.set('ads_enabled', v); }

  static getLsPin(): string { return this.get('ls_pin', '1234'); }
  static setLsPin(v: string): void { this.set('ls_pin', v); }

  static getFingerprint(): string {
    let fp = this.get('fingerprint', '');
    if (!fp) {
      fp = 'hn-' + Math.random().toString(36).substring(2, 12);
      this.set('fingerprint', fp);
    }
    return fp;
  }
}
