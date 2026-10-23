export type AdSlot =
  | 'fileListTop' | 'fileListBottom'
  | 'mainMenu' | 'splash' | 'previewBottom';

export type AdType = 'image' | 'text' | 'native';
export type AdProviderName = 'local' | 'petal' | 'custom';

export interface AdItem {
  id: string;
  slot: AdSlot;
  type: AdType;
  title: string;
  desc?: string;
  imageUrl?: string;
  targetUrl?: string;
  weight: number;
  startAt?: number;
  endAt?: number;
  enabled: boolean;
  adSlotId?: string;
}

export interface AdConfig {
  enabled: boolean;
  provider: AdProviderName;
  refreshIntervalSec: number;
  slots: AdItem[];
}

export interface AdEvent {
  adId: string;
  slot: AdSlot;
  type: 'impression' | 'click';
  ts: number;
  user?: string;
}

export interface AdProvider {
  name: AdProviderName;
  init(ctx?: unknown): Promise<void>;
  fetchAds(slot: AdSlot, count: number): Promise<AdItem[]>;
}
