import { FileItem } from '../model/ApiTypes';
import { DeviceUtil } from '../util/DeviceUtil';

@Component
export struct FileItemView {
  @Prop item: FileItem = { name: '', dir: false, size: 0, path: '' };
  onTap: (item: FileItem) => void = () => {};
  onLongPress: (item: FileItem) => void = () => {};

  build() {
    Row({ space: 12 }) {
      Text(this.item.dir ? '📁' : '📄').fontSize(28).width(40)
      Column({ space: 4 }) {
        Text(this.item.name).fontSize(16).fontWeight(FontWeight.Medium)
          .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(this.item.dir ? '文件夹' : DeviceUtil.formatSize(this.item.size))
          .fontSize(12).fontColor('#666666')
      }
      .layoutWeight(1).alignItems(HorizontalAlign.Start)
      Text('›').fontSize(20).fontColor('#999999')
    }
    .padding(12)
    .backgroundColor('#FFFFFF')
    .borderRadius(8)
    .width('100%')
    .onClick(() => this.onTap(this.item))
    .gesture(
      LongPressGesture({ duration: 500 }).onAction(() => this.onLongPress(this.item))
    )
  }
}
