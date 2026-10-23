import { socket } from '@kit.NetworkKit';
import { common } from '@kit.AbilityKit';
import { SettingsManager } from '../manager/SettingsManager';
import { LogManager } from '../manager/LogManager';

export class LocalSendDiscovery {
  private udp: socket.UDPSocket;
  private running: boolean = false;

  constructor(_ctx: common.Context) {
    this.udp = socket.constructUDPSocketInstance();
  }

  start(): void {
    this.running = true;
    this.udp.bind({ address: '224.0.0.167', port: 53317, family: 1 }, () => {
      try {
        this.udp.setMulticastTTL(4);
        this.udp.joinGroup({ address: '224.0.0.167' });
      } catch (_) {}
    });
    this.udp.on('message', (info: socket.SocketMessageInfo) => {
      if (!this.running) return;
      const text = new TextDecoder().decode(new Uint8Array(info.message));
      if (text.includes('"fingerprint"') && !text.includes(SettingsManager.getFingerprint())) {
        const reply = JSON.stringify({
          alias: SettingsManager.getDeviceAlias(),
          version: '2.2',
          deviceModel: 'HarmonyOS',
          deviceType: 'desktop',
          fingerprint: SettingsManager.getFingerprint(),
          port: 53317,
          protocol: 'http',
          download: false
        });
        this.udp.send({
          data: new TextEncoder().encode(reply).buffer,
          address: { address: info.remoteInfo.address, port: info.remoteInfo.port, family: 1 }
        });
      }
    });
    LogManager.add('LocalSend', 'UDP 发现服务启动');
  }

  stop(): void {
    this.running = false;
    try { this.udp.off('message'); this.udp.close(); } catch (_) {}
  }
}
