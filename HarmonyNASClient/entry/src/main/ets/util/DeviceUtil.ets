import { deviceInfo } from '@kit.BasicServicesKit';

export enum DeviceCategory {
  Phone,
  Tablet,
  TV,
  Wearable,
  Desktop,
  Unknown
}

export class DeviceUtil {
  static category(): DeviceCategory {
    try {
      const t = deviceInfo.deviceType.toLowerCase();
      if (t === 'phone' || t === 'default') return DeviceCategory.Phone;
      if (t === 'tablet') return DeviceCategory.Tablet;
      if (t === 'tv' || t === 'smartvision') return DeviceCategory.TV;
      if (t === 'wearable') return DeviceCategory.Wearable;
      if (t === '2in1' || t === 'pc') return DeviceCategory.Desktop;
    } catch (_) {}
    return DeviceCategory.Unknown;
  }

  static isTV(): boolean { return DeviceUtil.category() === DeviceCategory.TV; }
  static isWearable(): boolean { return DeviceUtil.category() === DeviceCategory.Wearable; }
  static isDesktop(): boolean { return DeviceUtil.category() === DeviceCategory.Desktop; }
  static isTablet(): boolean { return DeviceUtil.category() === DeviceCategory.Tablet; }

  /** TV / 手表需要遥控器 / 表冠焦点导航 */
  static needFocus(): boolean {
    return DeviceUtil.isTV() || DeviceUtil.isWearable();
  }

  static formatSize(size: number): string {
    if (size < 1024) return `${size} B`;
    if (size < 1024 * 1024) return `${(size / 1024).toFixed(1)} KB`;
    if (size < 1024 * 1024 * 1024) return `${(size / 1024 / 1024).toFixed(1)} MB`;
    return `${(size / 1024 / 1024 / 1024).toFixed(2)} GB`;
  }
}
