import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { backgroundTaskManager } from '@kit.BackgroundTasksKit';
import { NasService } from '../service/NasService';
import { LogManager } from '../manager/LogManager';

export default class EntryAbility extends UIAbility {
  onCreate(_w: Want, _l: AbilityConstant.LaunchParam): void {
    LogManager.add('SYSTEM', 'EntryAbility onCreate');
  }

  async onWindowStageCreate(windowStage: window.WindowStage): Promise<void> {
    windowStage.loadContent('pages/Index');

    try {
      const request: backgroundTaskManager.ContinuousTaskRequest = {
        context: this.context,
        reason: 'NAS 文件传输服务',
        isPersistent: true,
        backgroundMode: backgroundTaskManager.BackgroundMode.DATA_TRANSFER
      };
      await backgroundTaskManager.startBackgroundRunning(request);
      LogManager.add('SYSTEM', '长时任务 DATA_TRANSFER 已申请');
    } catch (e) {
      LogManager.add('SYSTEM', '长时任务申请失败: ' + (e as Error).message);
    }

    NasService.get().start(this.context).catch((e: Error) => {
      LogManager.add('SYSTEM', 'NAS 启动失败: ' + e.message);
    });
  }

  onDestroy(): void {
    NasService.get().stop();
  }
}
