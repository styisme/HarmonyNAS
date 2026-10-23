import { common } from '@kit.AbilityKit';
import { LogManager } from './LogManager';
import { SettingsManager } from './SettingsManager';
import { AdConfig, AdItem, AdSlot, AdEvent, AdProvider } from '../model/AdTypes';

const DEFAULT: AdConfig = {
  enabled: false, provider: 'local', refreshIntervalSec: 300, slots: []
};

class LocalProvider implements AdProvider {
  name: 'local' | 'petal' | 'custom' = 'local';
  private items: AdItem[] = [];

  async init(ctx?: unknown): Promise<void> {
    try {
      const raw = await (ctx as common.Context).resourceManager.getRawFileContent('ad.json');
      const cfg = JSON.parse(new TextDecoder().decode(new Uint8Array(raw))) as AdConfig;
      this.items = (cfg.slots ?? []).filter(a => a.enabled !== false);
    } catch (_) { this.items = []; }
  }

  async fetchAds(slot: AdSlot, n: number): Promise<AdItem[]> {
    const now = Date.now();
    return this.items
      .filter(a => a.slot === slot &&
        (!a.startAt || a.startAt <= now) &&
        (!a.endAt || a.endAt >= now))
      .slice(0, n);
  }
}

class PetalProvider implements AdProvider {
  name: 'local' | 'petal' | 'custom' = 'petal';
  private units: Array<{ slot: string; adSlotId: string; adType: number }> = [];

  async init(ctx?: unknown): Promise<void> {
    try {
      const raw = await (ctx as common.Context).resourceManager.getRawFileContent('petal_ad.json');
      const cfg = JSON.parse(new TextDecoder().decode(new Uint8Array(raw)));
      this.units = (cfg.adUnits ?? []).filter((u: { enabled: boolean }) => u.enabled);
    } catch (_) { this.units = []; }
  }

  async fetchAds(slot: AdSlot, _n: number): Promise<AdItem[]> {
    const u = this.units.find(x => x.slot === slot);
    if (!u) return [];
    return [{
      id: u.adSlotId, slot, type: 'native', title: '', weight: 1,
      enabled: true, adSlotId: u.adSlotId
    }];
  }
}

export class AdManager {
  private static provider: AdProvider = new LocalProvider();
  private static config: AdConfig = { ...DEFAULT };
  private static events: AdEvent[] = [];
  private static loaded: boolean = false;

  static async load(ctx: common.Context): Promise<void> {
    if (this.loaded) return;
    try {
      const raw = await ctx.resourceManager.getRawFileContent('ad.json');
      this.config = JSON.parse(new TextDecoder().decode(new Uint8Array(raw))) as AdConfig;
    } catch (_) { this.config = { ...DEFAULT }; }

    this.provider = this.config.provider === 'petal'
      ? new PetalProvider() : new LocalProvider();
    await this.provider.init(ctx);
    this.loaded = true;
    LogManager.add('AD', `provider=${this.provider.name}, enabled=${this.isEnabled()}`);
  }

  static isEnabled(): boolean {
    return this.config.enabled && SettingsManager.isAdsEnabled();
  }

  static getRefreshInterval(): number {
    return this.config.refreshIntervalSec ?? 300;
  }

  static async getAds(slot: AdSlot, n: number = 1): Promise<AdItem[]> {
    if (!this.isEnabled()) return [];
    return this.provider.fetchAds(slot, Math.max(1, Math.min(n, 10)));
  }

  static track(ev: AdEvent): void {
    this.events.unshift(ev);
    if (this.events.length > 1000) this.events.pop();
    LogManager.add('AD', `${ev.type} ${ev.adId}@${ev.slot}`);
  }
}
