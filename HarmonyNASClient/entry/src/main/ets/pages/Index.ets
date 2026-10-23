import { mediaquery } from '@kit.ArkUI';
import { AppStore } from '../viewmodel/AppStore';
import { AdaptiveScaffold } from '../components/AdaptiveScaffold';
import { HomePage } from './HomePage';
import { PhotosPage } from './PhotosPage';
import { SettingsPage } from './SettingsPage';
import { LayoutDecision } from '../model/ApiTypes';
import { DeviceUtil } from '../util/DeviceUtil';
import { LogManager } from '../util/LogUtil';

@Entry
@Component
struct Index {
  @State decision: LayoutDecision = AppStore.decision();
  @State activeTab: number = 0;
  private listener: mediaquery.MediaQueryListener | null = null;

  aboutToAppear(): void {
    this.listener = mediaquery.matchMediaSync('(min-width: 600vp)');
    this.listener.on('change', (r: mediaquery.MediaQueryResult) => {
      // 用窗口宽度重新计算断点
      const vp = r.matches ? 600 : 360;
      AppStore.onResize(vp);
      this.decision = AppStore.decision();
      LogManager.add('UI', `resize -> ${this.decision.mode} cols=${this.decision.columns}`);
    });
    AppStore.onResize(this.decision.columns > 1 ? 800 : 360);
    this.decision = AppStore.decision();
  }

  aboutToDisappear(): void { this.listener?.off('change'); }

  private title(): string {
    switch (this.activeTab) {
      case 0: return '文件';
      case 1: return '相册';
      case 2: return '剪贴板';
      case 3: return '设置';
      default: return 'HarmonyNAS';
    }
  }

  build() {
    AdaptiveScaffold({
      decision: this.decision,
      title: this.title(),
      activeTab: this.activeTab,
      onSelectTab: (i: number) => {
        this.activeTab = i;
        if (i === 2) {
          // 剪贴板直接跳到设置页的剪贴板区块
        }
      },
      topAction: () => {
        Row() {
          Text(AppStore.hasConfig() ? '已连接' : '未配置')
            .fontSize(12).fontColor(AppStore.hasConfig() ? '#4CAF50' : '#B3261E')
        }
      },
      content: () => {
        if (!AppStore.hasConfig()) {
          SettingsPage({ decision: this.decision })
        } else if (this.activeTab === 0) {
          HomePage({ decision: this.decision })
        } else if (this.activeTab === 1) {
          PhotosPage({ decision: this.decision })
        } else {
          SettingsPage({ decision: this.decision })
        }
      }
    })
  }
}
