import { common } from '@kit.AbilityKit';
import { LogManager } from './LogManager';

export interface VersionInfo {
  versionName: string;
  versionCode: number;
  buildDate: string;
  channel: string;
}

const DEFAULT: VersionInfo = {
  versionName: '0.0.0', versionCode: 0, buildDate: '', channel: 'unknown'
};

export class VersionManager {
  private static current: VersionInfo = { ...DEFAULT };
  private static loaded: boolean = false;

  static async load(ctx: common.Context): Promise<void> {
    if (this.loaded) return;
    try {
      this.current = await this.loadFromSource(ctx);
      this.loaded = true;
      LogManager.add('VERSION',
        `已加载 ${this.current.versionName} (${this.current.versionCode})`);
    } catch (e) {
      LogManager.add('VERSION', '读取失败: ' + (e as Error).message);
    }
  }

  static async reload(ctx: common.Context): Promise<void> {
    this.loaded = false;
    await this.load(ctx);
  }

  static get(): VersionInfo { return { ...this.current }; }

  private static async loadFromSource(ctx: common.Context): Promise<VersionInfo> {
    const raw = await ctx.resourceManager.getRawFileContent('version.json');
    const text = new TextDecoder().decode(new Uint8Array(raw));
    const obj = JSON.parse(text) as VersionInfo;
    if (!obj.versionName) throw new Error('version.json 缺少 versionName');
    return {
      versionName: String(obj.versionName),
      versionCode: Number(obj.versionCode ?? 0),
      buildDate: String(obj.buildDate ?? ''),
      channel: String(obj.channel ?? 'stable')
    };
  }
}
