import { ServerConfig } from '../model/ApiTypes';
import { AppStore } from '../viewmodel/AppStore';
import { NasClient } from '../service/NasClient';
import { DiscoveryService, DiscoveredServer } from '../service/DiscoveryService';
import { DeviceUtil } from '../util/DeviceUtil';

@Component
export struct SettingsPage {
  @Prop decision: import('../model/ApiTypes').LayoutDecision;

  @State host: string = '';
  @State port: number = 8080;
  @State user: string = 'admin';
  @State pass: string = 'admin';
  @State alias: string = '';
  @State connected: boolean = false;
  @State scanning: boolean = false;
  @State scanned: DiscoveredServer[] = [];
  @State clip: string = '';
  @State clipLoading: boolean = false;

  aboutToAppear(): void {
    const cfg = AppStore.config();
    if (cfg) {
      this.host = cfg.host;
      this.port = cfg.port;
      this.user = cfg.user;
      this.pass = cfg.pass;
      this.alias = cfg.alias;
      this.connected = true;
    }
  }

  async doConnect(): Promise<void> {
    const cfg: ServerConfig = {
      host: this.host.trim(), port: this.port,
      user: this.user, pass: this.pass, alias: this.alias
    };
    AppStore.setConfig(cfg);
    try {
      const st = await NasClient.get().status();
      this.connected = true;
      AlertDialog.show({
        title: '连接成功',
        message: `状态: ${st.clipboardEnabled ? '剪贴板开启' : '剪贴板关闭'}`,
        confirm: { value: 'OK', action: () => {} }
      });
    } catch (e) {
      this.connected = false;
      AlertDialog.show({ title: '连接失败', message: String(e), confirm: { value: 'OK', action: () => {} } });
    }
  }

  async doScan(): Promise<void> {
    this.scanning = true;
    this.scanned = [];
    try {
      this.scanned = await DiscoveryService.scan(this.port);
      if (this.scanned.length === 0) {
        AlertDialog.show({ title: '未发现设备', message: '请检查网络或手动输入 IP', confirm: { value: 'OK', action: () => {} } });
      }
    } catch (e) {
      AlertDialog.show({ title: '扫描失败', message: String(e), confirm: { value: 'OK', action: () => {} } });
    } finally {
      this.scanning = false;
    }
  }

  async loadClipboard(): Promise<void> {
    this.clipLoading = true;
    try { this.clip = await NasClient.get().clipboard(); }
    catch (_) {}
    finally { this.clipLoading = false; }
  }

  async saveClipboard(): Promise<void> {
    try {
      await NasClient.get().saveClipboard(this.clip);
      AlertDialog.show({ title: '已同步', message: '剪贴板内容已上传', confirm: { value: 'OK', action: () => {} } });
    } catch (e) {
      AlertDialog.show({ title: '同步失败', message: String(e), confirm: { value: 'OK', action: () => {} } });
    }
  }

  build() {
    Scroll() {
      Column({ space: 16 }) {
        // ============ 服务器配置 ============
        Text('服务器配置').fontSize(16).fontWeight(FontWeight.Bold).width('100%')
        Column({ space: 8 }) {
          this.field('IP / 主机', this.host, (v: string) => { this.host = v; })
          this.field('端口', String(this.port), (v: string) => { this.port = parseInt(v) || 8080; }, 'number')
          this.field('用户名', this.user, (v: string) => { this.user = v; })
          this.field('密码', this.pass, (v: string) => { this.pass = v; }, 'password')
          this.field('别名（可选）', this.alias, (v: string) => { this.alias = v; })
        }
        Row({ space: 8 }) {
          Button('连接').onClick(() => this.doConnect())
          Button(this.scanning ? '扫描中…' : '🔍 扫描局域网').enabled(!this.scanning)
            .onClick(() => this.doScan())
        }

        if (this.scanned.length > 0) {
          Text(`发现 ${this.scanned.length} 台设备`).fontSize(14).fontColor('#666')
          ForEach(this.scanned, (s: DiscoveredServer) => {
            Row({ space: 8 }) {
              Text(`${s.ip}:${s.port}`).fontSize(14).layoutWeight(1)
              Button('使用').onClick(() => {
                this.host = s.ip;
                this.port = s.port;
              })
            }
            .padding(8).backgroundColor('#FFFFFF').borderRadius(8).width('100%')
          }, (s: DiscoveredServer) => `${s.ip}:${s.port}`)
        }

        Divider().margin({ top: 8, bottom: 8 })

        // ============ 局域网剪贴板 ============
        Text('局域网剪贴板').fontSize(16).fontWeight(FontWeight.Bold).width('100%')
        TextArea({ text: this.clip, placeholder: '在此输入内容…' })
          .height(120)
          .onChange((v: string) => { this.clip = v; })
        Row({ space: 8 }) {
          Button('拉取').onClick(() => this.loadClipboard())
          Button('同步到服务端').onClick(() => this.saveClipboard())
        }

        Divider().margin({ top: 8, bottom: 8 })

        // ============ 设备信息 ============
        Text('设备信息').fontSize(16).fontWeight(FontWeight.Bold).width('100%')
        Text(`类别: ${DeviceUtil.category()}`).fontSize(14).fontColor('#666')
        Text(`布局: ${this.decision.mode} / 列数 ${this.decision.columns} / 焦点 ${this.decision.focusMode}`)
          .fontSize(14).fontColor('#666')
        Text(`已连接: ${this.connected ? '是' : '否'}`).fontSize(14).fontColor('#666')

        Blank().height(32)
      }
      .padding(16).width('100%')
    }
    .width('100%').height('100%')
  }

  @Builder
  field(label: string, value: string, onChange: (v: string) => void, type: string = 'text') {
    Row({ space: 8 }) {
      Text(label).fontSize(14).width(90).textAlign(TextAlign.End)
      TextInput({ text: value })
        .type(type === 'password' ? InputType.Password : (type === 'number' ? InputType.Number : InputType.Normal))
        .layoutWeight(1)
        .onChange((v: string) => onChange(v))
    }
  }
}
