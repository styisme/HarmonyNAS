import { util } from '@kit.ArkTS';
import { DatabaseManager } from './DatabaseManager';
import { SettingsManager } from './SettingsManager';

export class AuthManager {
  private static enabled: boolean = true;
  private static currentUser: string = 'admin';

  static init(): void { AuthManager.enabled = SettingsManager.isAuthEnabled(); }

  static isEnabled(): boolean { return AuthManager.enabled; }
  static setEnabled(v: boolean): void { AuthManager.enabled = v; }
  static getCurrentUser(): string { return AuthManager.currentUser; }

  static verifyRole(authHeader: string | undefined): number {
    if (!AuthManager.enabled) { AuthManager.currentUser = 'admin'; return 1; }
    if (!authHeader || !authHeader.startsWith('Basic ')) return 0;
    try {
      const decoded = new util.Base64Helper().decodeToString(authHeader.substring(6).trim());
      const idx = decoded.indexOf(':');
      if (idx < 0) return 0;
      const user = decoded.substring(0, idx);
      const pass = decoded.substring(idx + 1);
      const role = DatabaseManager.verifyUser(user, pass);
      if (role > 0) { AuthManager.currentUser = user; return role; }
    } catch (_) {}
    return 0;
  }

  static verify(authHeader: string | undefined): boolean {
    return AuthManager.verifyRole(authHeader) > 0;
  }
}
