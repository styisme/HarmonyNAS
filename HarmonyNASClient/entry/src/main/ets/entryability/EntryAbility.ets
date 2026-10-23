import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { AppStore } from '../viewmodel/AppStore';
import { AuthStore } from '../service/AuthStore';
import { LogManager } from '../util/LogUtil';

export default class EntryAbility extends UIAbility {
  onCreate(_w: Want, _l: AbilityConstant.LaunchParam): void {
    LogManager.add('SYSTEM', 'EntryAbility onCreate');
    AuthStore.init(this.context);
    AppStore.init(360);
    LogManager.add('SYSTEM', 'AppStore 已初始化');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    windowStage.loadContent('pages/Index');
  }

  onWindowStageDestroy(): void {}
  onDestroy(): void {}
}
