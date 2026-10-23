import { FileItem } from '../model/ApiTypes';
import { NasClient } from '../service/NasClient';
import { DeviceUtil } from '../util/DeviceUtil';
import { router } from '@kit.ArkUI';

@Component
export struct PreviewPage {
  @State item: FileItem = { name: '', dir: false, size: 0, path: '' };
  @State textContent: string = '';
  @State loading: boolean = true;
  @State error: string = '';

  aboutToAppear(): void {
    const params = router.getParams() as Record<string, Object>;
    const it = params['item'] as FileItem;
    if (it) {
      this.item = it;
      this.load();
    } else {
      this.loading = false;
      this.error = '无参数';
    }
  }

  private ext(): string {
    const idx = this.item.name.lastIndexOf('.');
    return idx >= 0 ? this.item.name.substring(idx + 1).toLowerCase() : '';
  }

  async load(): Promise<void> {
    this.loading = true;
    try {
      const ext = this.ext();
      const isText = ['txt', 'md', 'json', 'js', 'ts', 'html', 'css', 'py', 'log', 'xml'].includes(ext);
      if (isText) {
        this.textContent = await NasClient.get().readText(this.item.path);
      }
    } catch (e) {
      this.error = String(e);
    } finally {
      this.loading = false;
    }
  }

  build() {
    Column() {
      Row() {
        Button('←').onClick(() => router.back())
        Text(this.item.name).fontSize(16).fontWeight(FontWeight.Medium)
          .layoutWeight(1).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
        Button('下载').onClick(() => { /* 交给系统下载器 */ })
      }
      .padding(12).width('100%').backgroundColor('#FFFFFF')

      if (this.loading) {
        LoadingProgress().width(48).height(48).margin(48)
      } else if (this.error) {
        Text('加载失败: ' + this.error).fontColor('#B3261E').padding(24)
      } else {
        this.renderContent()
      }
    }
    .width('100%').height('100%').backgroundColor('#F5F5F5')
  }

  @Builder
  renderContent() {
    Column() {
      if (['jpg', 'jpeg', 'png', 'gif', 'webp'].includes(this.ext())) {
        Image(NasClient.get().downloadUrl(this.item.path))
          .objectFit(ImageFit.Contain)
          .width('100%').height('100%')
          .interpolation(ImageInterpolation.High)
      } else if (['mp4', 'webm', 'mkv'].includes(this.ext())) {
        Video({ src: NasClient.get().downloadUrl(this.item.path) })
          .controls(true).autoPlay(true)
          .width('100%').height('100%')
      } else if (['mp3', 'wav', 'flac'].includes(this.ext())) {
        Column() {
          Text('🎵 ' + this.item.name).fontSize(20).margin({ top: 64, bottom: 24 })
          Text(DeviceUtil.formatSize(this.item.size)).fontSize(14).fontColor('#999')
        }
      } else if (this.textContent) {
        Scroll() {
          Text(this.textContent)
            .fontSize(13).fontFamily('monospace')
            .width('100%').padding(16)
        }.width('100%').height('100%')
      } else {
        Text('暂不支持预览此类型').fontSize(14).fontColor('#999').padding(48)
      }
    }.width('100%').height('100%')
  }
}
