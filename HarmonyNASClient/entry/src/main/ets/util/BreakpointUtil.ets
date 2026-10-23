export type Breakpoint = 'xs' | 'sm' | 'md' | 'lg' | 'xl';

export class BreakpointUtil {
  static of(widthVp: number): Breakpoint {
    if (widthVp < 320) return 'xs';   // 手表
    if (widthVp < 600) return 'sm';   // 手机
    if (widthVp < 840) return 'md';   // 平板竖
    if (widthVp < 1440) return 'lg';  // 平板横 / TV
    return 'xl';                       // 2in1 / 大屏
  }

  static columns(bp: Breakpoint): number {
    switch (bp) {
      case 'xs': return 1;
      case 'sm': return 1;
      case 'md': return 3;
      case 'lg': return 4;
      case 'xl': return 6;
    }
  }

  static isHandheld(bp: Breakpoint): boolean {
    return bp === 'xs' || bp === 'sm';
  }
}
