import { ServerConfig, FileItem, LayoutDecision } from '../model/ApiTypes';
import { AuthStore } from '../service/AuthStore';
import { NasClient } from '../service/NasClient';
import { DeviceAdapter } from '../util/DeviceAdapter';

export class AppStore {
  private static _cfg: ServerConfig | null = null;
  private static _decision: LayoutDecision | null = null;
  private static _widthVp: number = 360;

  static init(widthVp: number): void {
    AppStore._widthVp = widthVp;
    AppStore._decision = DeviceAdapter.decide(widthVp);
    const saved = AuthStore.load();
    if (saved) {
      AppStore._cfg = saved;
      NasClient.get().configure(saved);
    }
  }

  static setConfig(cfg: ServerConfig): void {
    AppStore._cfg = cfg;
    AuthStore.save(cfg);
    NasClient.get().configure(cfg);
  }

  static clearConfig(): void {
    AppStore._cfg = null;
    AuthStore.clear();
  }

  static config(): ServerConfig | null { return AppStore._cfg; }
  static hasConfig(): boolean { return AppStore._cfg !== null; }

  static onResize(widthVp: number): void {
    AppStore._widthVp = widthVp;
    AppStore._decision = DeviceAdapter.decide(widthVp);
  }

  static decision(): LayoutDecision {
    if (!AppStore._decision) {
      AppStore._decision = DeviceAdapter.decide(AppStore._widthVp);
    }
    return AppStore._decision;
  }
}
