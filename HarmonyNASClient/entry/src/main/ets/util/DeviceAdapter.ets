import { BreakpointUtil, Breakpoint } from './BreakpointUtil';
import { DeviceUtil, DeviceCategory } from './DeviceUtil';
import { LayoutDecision } from '../model/ApiTypes';

/**
 * 多设备适配核心决策器：
 * - TV / 手表：强制焦点导航 + 固定列数网格
 * - 平板：双栏 split（左目录树，右文件列表）
 * - 2in1 / 大屏：三栏布局
 * - 手机：单栏 + 底部 Tab
 */
export class DeviceAdapter {
  static decide(widthVp: number): LayoutDecision {
    const cat = DeviceUtil.category();
    const bp = BreakpointUtil.of(widthVp);

    if (cat === DeviceCategory.TV) {
      return {
        mode: 'grid-full',
        layout: 'grid',
        columns: 4,
        showFolderTree: false,
        focusMode: true,
        showBottomTabs: false,
        showTopBar: true
      };
    }

    if (cat === DeviceCategory.Wearable) {
      return {
        mode: 'stack',
        layout: 'list',
        columns: 1,
        showFolderTree: false,
        focusMode: true,
        showBottomTabs: false,
        showTopBar: true
      };
    }

    if (cat === DeviceCategory.Desktop && bp !== 'sm' && bp !== 'xs') {
      return {
        mode: 'split',
        layout: 'grid',
        columns: 5,
        showFolderTree: true,
        focusMode: false,
        showBottomTabs: false,
        showTopBar: true
      };
    }

    if (bp === 'md' || bp === 'lg') {
      return {
        mode: 'split',
        layout: 'grid',
        columns: BreakpointUtil.columns(bp),
        showFolderTree: true,
        focusMode: false,
        showBottomTabs: false,
        showTopBar: true
      };
    }

    // 默认手机
    return {
      mode: 'stack',
      layout: 'list',
      columns: 1,
      showFolderTree: false,
      focusMode: false,
      showBottomTabs: true,
      showTopBar: true
    };
  }

  static breakpoint(widthVp: number): Breakpoint {
    return BreakpointUtil.of(widthVp);
  }
}
