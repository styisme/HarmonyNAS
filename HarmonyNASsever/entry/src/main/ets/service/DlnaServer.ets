import { socket } from '@kit.NetworkKit';
import { common } from '@kit.AbilityKit';
import { SettingsManager } from '../manager/SettingsManager';
import { LogManager } from '../manager/LogManager';

export class DlnaServer {
  private udp: socket.UDPSocket;
  private running: boolean = false;

  constructor(_ctx: common.Context) {
    this.udp = socket.constructUDPSocketInstance();
  }

  start(): void {
    this.running = true;
    this.udp.bind({ address: '0.0.0.0', port: 1900, family: 1 }, () => {
      try {
        this.udp.setMulticastTTL(4);
        this.udp.joinGroup({ address: '239.255.255.250' });
      } catch (_) {}
    });
    this.udp.on('message', (info: socket.SocketMessageInfo) => {
      if (!this.running) return;
      const text = new TextDecoder().decode(new Uint8Array(info.message));
      if (text.startsWith('M-SEARCH')) {
        const response = 'HTTP/1.1 200 OK\r\n' +
          'CACHE-CONTROL: max-age=1800\r\nEXT:\r\n' +
          'LOCATION: http://127.0.0.1:' + SettingsManager.getWebPort() + '/dlna/description.xml\r\n' +
          'SERVER: HarmonyOS/1.0 UPnP/1.0 HarmonyNAS/1.0\r\n' +
          'ST: urn:schemas-upnp-org:device:MediaServer:1\r\n' +
          'USN: uuid:' + SettingsManager.getFingerprint() +
          '::urn:schemas-upnp-org:device:MediaServer:1\r\n\r\n';
        this.udp.send({
          data: new TextEncoder().encode(response).buffer,
          address: { address: info.remoteInfo.address, port: info.remoteInfo.port, family: 1 }
        });
      }
    });
    LogManager.add('DLNA', 'SSDP 启动');
  }

  stop(): void {
    this.running = false;
    try { this.udp.off('message'); this.udp.close(); } catch (_) {}
  }
}
