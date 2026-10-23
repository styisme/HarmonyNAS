import { LayoutDecision } from '../model/ApiTypes';

/**
 * 多设备外壳：
 * - 手机：顶部标题 + 内容 + 底部 Tabs
 * - 平板/2in1：左侧导航栏 + 内容（双栏）
 * - TV：全屏网格（无底部导航）
 * - 手表：极简顶栏 + 内容（单栏，无底部导航）
 *
 * 通过 @BuilderParam 注入内容，避免布局耦合。
 */
@Component
export struct AdaptiveScaffold {
  @Prop decision: LayoutDecision = {
    mode: 'stack', layout: 'list', columns: 1,
    showFolderTree: false, focusMode: false,
    showBottomTabs: true, showTopBar: true
  };
  @Prop title: string = '';
  @Prop selectedTab: number = 0;
  @Link activeTab: number;

  onSelectTab: (index: number) => void = () => {};

  @BuilderParam content: () => void = () => {};
  @BuilderParam sideContent: () => void = () => {};
  @BuilderParam topAction: () => void = () => {};

  build() {
    if (this.decision.mode === 'split') {
      // ============ 平板 / 2in1：双栏 ============
      Row() {
        // 左侧导航
        Column() {
          Text('HarmonyNAS').fontSize(20).fontWeight(FontWeight.Bold)
            .margin({ top: 24, bottom: 24 })
          this.sideNavItem('📁 文件', 0)
          this.sideNavItem('🖼️ 相册', 1)
          this.sideNavItem('📋 剪贴板', 2)
          this.sideNavItem('⚙️ 设置', 3)
          Blank()
        }
        .width(220).height('100%')
        .backgroundColor('#F0F0F0')
        .padding({ left: 12, right: 12 })

        // 右侧
        Column() {
          if (this.decision.showTopBar) {
            Row() {
              Text(this.title).fontSize(22).fontWeight(FontWeight.Bold).layoutWeight(1)
              this.topAction()
            }
            .width('100%').height(64).padding({ left: 24, right: 24 })
            .backgroundColor('#FFFFFF')
            .border({ width: { bottom: 1 }, color: '#EEEEEE' })
          }
          Column() { this.content() }.layoutWeight(1).width('100%')
        }
        .layoutWeight(1).height('100%')
      }
      .width('100%').height('100%')
      .backgroundColor('#F5F5F5')
    } else if (this.decision.mode === 'grid-full') {
      // ============ TV：全屏，无底部导航 ============
      Column() {
        if (this.decision.showTopBar) {
          Row() {
            Text(this.title).fontSize(28).fontWeight(FontWeight.Bold).layoutWeight(1)
            this.topAction()
          }
          .width('100%').padding({ left: 48, right: 48, top: 32, bottom: 24 })
        }
        Column() { this.content() }.layoutWeight(1).width('100%')
      }
      .width('100%').height('100%').backgroundColor('#0F1115')
    } else {
      // ============ 手机 / 手表：单栏 + 底部 Tab ============
      Column() {
        if (this.decision.showTopBar) {
          Row() {
            Text(this.title).fontSize(this.decision.focusMode ? 18 : 22)
              .fontWeight(FontWeight.Bold).layoutWeight(1)
            this.topAction()
          }
          .width('100%').height(this.decision.focusMode ? 48 : 64)
          .padding({ left: this.decision.focusMode ? 12 : 20,
                     right: this.decision.focusMode ? 12 : 20 })
          .backgroundColor('#FFFFFF')
          .border({ width: { bottom: 1 }, color: '#EEEEEE' })
        }
        Column() { this.content() }.layoutWeight(1).width('100%')
        if (this.decision.showBottomTabs) {
          Row() {
            this.tabItem('📁', '文件', 0)
            this.tabItem('🖼️', '相册', 1)
            this.tabItem('📋', '剪贴板', 2)
            this.tabItem('⚙️', '设置', 3)
          }
          .width('100%').height(64)
          .backgroundColor('#FFFFFF')
          .border({ width: { top: 1 }, color: '#EEEEEE' })
        }
      }
      .width('100%').height('100%').backgroundColor('#F5F5F5')
    }
  }

  @Builder
  sideNavItem(label: string, index: number) {
    Text(label)
      .fontSize(16)
      .fontWeight(this.activeTab === index ? FontWeight.Bold : FontWeight.Normal)
      .fontColor(this.activeTab === index ? '#1976D2' : '#333333')
      .width('100%')
      .padding({ top: 14, bottom: 14, left: 12 })
      .borderRadius(8)
      .backgroundColor(this.activeTab === index ? '#E3F2FD' : 'transparent')
      .onClick(() => {
        this.activeTab = index;
        this.onSelectTab(index);
      })
  }

  @Builder
  tabItem(icon: string, label: string, index: number) {
    Column({ space: 2 }) {
      Text(icon).fontSize(20)
      Text(label)
        .fontSize(10)
        .fontColor(this.activeTab === index ? '#1976D2' : '#666666')
    }
    .layoutWeight(1)
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .onClick(() => {
      this.activeTab = index;
      this.onSelectTab(index);
    })
  }
}
