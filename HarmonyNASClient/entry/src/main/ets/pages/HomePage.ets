import { FileItem } from '../model/ApiTypes';
import { NasClient } from '../service/NasClient';
import { AppStore } from '../viewmodel/AppStore';
import { DeviceUtil } from '../util/DeviceUtil';
import { FileItemView } from '../components/FileItemView';
import { FileGrid } from '../components/FileGrid';
import { router } from '@kit.ArkUI';

@Component
export struct HomePage {
  @Prop decision: import('../model/ApiTypes').LayoutDecision;
  @State path: string = '/';
  @State files: FileItem[] = [];
  @State loading: boolean = false;
  @State keyword: string = '';
  @State searchMode: boolean = false;

  aboutToAppear(): void { this.refresh(); }

  async refresh(): Promise<void> {
    this.loading = true;
    try {
      const nas = NasClient.get();
      if (!nas.isReady()) { this.files = []; return; }
      this.files = this.searchMode && this.keyword
        ? await nas.search(this.keyword)
        : await nas.list(this.path);
    } catch (e) {
      console.error('list failed', e);
      this.files = [];
    } finally {
      this.loading = false;
    }
  }

  onFileTap(f: FileItem): void {
    if (f.dir) {
      this.path = f.path;
      this.searchMode = false;
      this.keyword = '';
      this.refresh();
    } else {
      router.pushUrl({ url: 'pages/PreviewPage', params: { item: f } });
    }
  }

  onFileLongPress(f: FileItem): void {
    const nas = NasClient.get();
    AlertDialog.show({
      title: f.name,
      message: f.dir ? '文件夹' : DeviceUtil.formatSize(f.size),
      primaryButton: {
        value: '分享',
        action: async () => {
          try {
            const token = await nas.share(f.path);
            const url = nas.downloadUrl(f.path).replace('/api/download?path=', '');
            AlertDialog.show({
              title: '分享成功',
              message: `${AppStore.config()?.host}/share/${token}`,
              confirm: { value: '确定', action: () => {} }
            });
          } catch (e) {
            AlertDialog.show({ title: '分享失败', message: String(e), confirm: { value: 'OK', action: () => {} } });
          }
        }
      },
      secondaryButton: {
        value: '删除',
        fontColor: '#B3261E',
        action: async () => {
          try { await nas.remove(f.path); this.refresh(); } catch (_) {}
        }
      }
    });
  }

  goUp(): void {
    if (this.path === '/') return;
    const parts = this.path.replace(/\/$/, '').split('/');
    parts.pop();
    this.path = parts.join('/') || '/';
    this.refresh();
  }

  build() {
    Column() {
      // 工具条：返回 + 路径 + 搜索 + 新建
      Row({ space: 8 }) {
        if (this.path !== '/' || this.searchMode) {
          Button('←').onClick(() => {
            if (this.searchMode) { this.searchMode = false; this.keyword = ''; this.refresh(); }
            else this.goUp();
          })
        }
        Text(this.searchMode ? '搜索: ' + this.keyword : this.path)
          .fontSize(14).fontColor('#666666').layoutWeight(1)
          .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
        if (!this.decision.showFolderTree) {
          Button('🔍').onClick(() => {
            AlertDialog.show({
              title: '全局搜索',
              message: '',
              customStyle: true,
              builder: undefined
            });
          })
        }
        Button('+').onClick(() => this.createFolder())
      }
      .padding({ left: 16, right: 16, top: 8, bottom: 8 })
      .width('100%')

      // 内容
      if (this.loading) {
        Column() { LoadingProgress().width(48).height(48) }.padding(48)
      } else if (this.files.length === 0) {
        Column() {
          Text('空目录').fontSize(14).fontColor('#999999')
        }.padding(48)
      } else if (this.decision.layout === 'grid') {
        FileGrid({
          items: this.files,
          columns: this.decision.columns,
          focusMode: this.decision.focusMode,
          onTap: (f: FileItem) => this.onFileTap(f),
          onLongPress: (f: FileItem) => this.onFileLongPress(f)
        }).layoutWeight(1)
      } else {
        List({ space: 8 }) {
          ForEach(this.files, (f: FileItem) => {
            ListItem() {
              FileItemView({
                item: f,
                onTap: (x: FileItem) => this.onFileTap(x),
                onLongPress: (x: FileItem) => this.onFileLongPress(x)
              })
            }
          }, (f: FileItem) => f.path)
        }
        .layoutWeight(1).padding(12).width('100%')
      }
    }
    .width('100%').height('100%')
  }

  async createFolder(): Promise<void> {
    try {
      await NasClient.get().mkdir(this.path, `新建文件夹_${Date.now()}`);
      this.refresh();
    } catch (_) {}
  }
}
