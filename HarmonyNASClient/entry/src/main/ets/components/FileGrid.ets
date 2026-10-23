import { FileItem } from '../model/ApiTypes';
import { DeviceUtil } from '../util/DeviceUtil';
import { FocusableCard } from './FocusableCard';

/**
 * 网格视图：列数由外部传入（TV=4 / 平板=3 / 桌面=5 / 手表=1）
 * - focusMode=true 时走 FocusableCard，支持遥控器/表冠
 * - 否则普通 GridItem
 */
@Component
export struct FileGrid {
  @Prop items: FileItem[] = [];
  @Prop columns: number = 3;
  @Prop focusMode: boolean = false;
  onTap: (item: FileItem) => void = () => {};
  onLongPress: (item: FileItem) => void = () => {};

  build() {
    Grid() {
      ForEach(this.items, (f: FileItem, index: number) => {
        GridItem() {
          if (this.focusMode) {
            FocusableCard({
              active: index === 0,
              onActivate: () => this.onTap(f),
              content: () => { this.cardContent(f) }
            })
          } else {
            Column({ space: 6 }) {
              this.cardContent(f)
            }
            .width('100%').height('100%')
            .backgroundColor('#FFFFFF')
            .borderRadius(12).padding(8)
            .onClick(() => this.onTap(f))
            .gesture(
              LongPressGesture({ duration: 500 }).onAction(() => this.onLongPress(f))
            )
          }
        }
      }, (f: FileItem) => f.path)
    }
    .columnsTemplate(`repeat(${this.columns}, 1fr)`)
    .columnsGap(12)
    .rowsGap(12)
    .padding(12)
    .width('100%')
    .height('100%')
  }

  @Builder
  cardContent(f: FileItem) {
    Column({ space: 6 }) {
      Text(f.dir ? '📁' : '📄')
        .fontSize(this.columns === 1 ? 32 : 44)
        .width('100%').textAlign(TextAlign.Center)
      Text(f.name)
        .fontSize(this.columns === 1 ? 14 : 12)
        .fontWeight(FontWeight.Medium)
        .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%').textAlign(TextAlign.Center)
      if (!f.dir && this.columns > 1) {
        Text(DeviceUtil.formatSize(f.size))
          .fontSize(10).fontColor('#999999').width('100%').textAlign(TextAlign.Center)
      }
    }
    .width('100%')
  }
}
