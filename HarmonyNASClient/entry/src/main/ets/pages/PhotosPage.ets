import { common } from '@kit.AbilityKit';
import { FileItem } from '../model/ApiTypes';
import { NasClient } from '../service/NasClient';
import { BackupService, BackupResult } from '../service/BackupService';
import { FileGrid } from '../components/FileGrid';

@Component
export struct PhotosPage {
  @Prop decision: import('../model/ApiTypes').LayoutDecision;
  @State photos: FileItem[] = [];
  @State backingUp: boolean = false;
  @State backupProgress: string = '';

  aboutToAppear(): void { this.refresh(); }

  async refresh(): Promise<void> {
    try {
      this.photos = await NasClient.get().photos();
    } catch (_) { this.photos = []; }
  }

  async startBackup(): Promise<void> {
    this.backingUp = true;
    try {
      const ctx = getContext(this) as common.UIAbilityContext;
      const result: BackupResult = await BackupService.run(ctx, (done, total, name) => {
        this.backupProgress = `(${done}/${total}) ${name}`;
      });
      AlertDialog.show({
        title: '备份完成',
        message: `上传 ${result.uploaded}，跳过 ${result.skipped}，失败 ${result.failed}`,
        confirm: { value: 'OK', action: () => {} }
      });
      this.refresh();
    } catch (e) {
      AlertDialog.show({ title: '备份失败', message: String(e), confirm: { value: 'OK', action: () => {} } });
    } finally {
      this.backingUp = false;
      this.backupProgress = '';
    }
  }

  build() {
    Column() {
      Row({ space: 8 }) {
        Text(`时光相册 (${this.photos.length})`).fontSize(14).fontColor('#666').layoutWeight(1)
        Button(this.backingUp ? this.backupProgress : '📥 备份照片')
          .enabled(!this.backingUp)
          .onClick(() => this.startBackup())
        Button('↻').onClick(() => this.refresh())
      }
      .padding(12).width('100%')

      if (this.photos.length === 0) {
        Column() { Text('暂无照片').fontSize(14).fontColor('#999') }.padding(48)
      } else {
        FileGrid({
          items: this.photos,
          columns: this.decision.columns,
          focusMode: this.decision.focusMode,
          onTap: (f: FileItem) => {}
        }).layoutWeight(1)
      }
    }
    .width('100%').height('100%')
  }
}
