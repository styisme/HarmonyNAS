import { LogManager } from '../manager/LogManager';
import { SettingsManager } from '../manager/SettingsManager';
import { VersionManager } from '../manager/VersionManager';
import { HttpServer } from '../service/HttpServer';

@Entry
@Component
struct Index {
  @State logs: string = '';
  @State ip: string = '127.0.0.1';
  @State port: number = 8080;
  @State version: string = '0.0.0';

  aboutToAppear(): void {
    this.port = SettingsManager.getWebPort();
    this.version = VersionManager.get().versionName;
    this.logs = LogManager.getAll();
    setInterval(() => {
      this.logs = LogManager.getAll();
    }, 1000);
  }

  build() {
    Column({ space: 12 }) {
      Text('HarmonyNAS')
        .fontSize(24).fontWeight(FontWeight.Bold)
        .margin({ top: 24 })

      Text(`版本 ${this.version}`)
        .fontSize(14).fontColor('#666')

      Text(`访问 http://${this.ip}:${this.port}`)
        .fontSize(16).fontColor('#1976D2')

      Divider()

      Text('运行日志')
        .fontSize(16).fontWeight(FontWeight.Medium)

      Scroll() {
        Text(this.logs)
          .fontSize(12).fontFamily('monospace')
          .width('100%').textAlign(TextAlign.Start)
      }
      .layoutWeight(1)
      .width('100%')
      .padding(12)
      .backgroundColor('#111')
      .borderRadius(8)
    }
    .padding(16)
    .width('100%').height('100%')
  }
}
