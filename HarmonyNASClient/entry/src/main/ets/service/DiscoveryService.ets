import { http } from '@kit.NetworkKit';
import { connection } from '@kit.NetworkKit';
import { util } from '@kit.ArkTS';
import { LogManager } from '../util/LogUtil';

export interface DiscoveredServer {
  ip: string;
  port: number;
}

/**
 * 局域网扫描：并发探测 192.168.x.1-254:8080/api/status
 * - 单次超时 300ms，并发 64
 * - 支持自定义网段（多设备/多网卡）
 */
export class DiscoveryService {
  static async localSubnets(): Promise<string[]> {
    const subs: string[] = [];
    try {
      const nets = connection.getAllNetsSync();
      for (const n of nets) {
        const addr = (n as connection.NetHandle).address;
        const idx = addr.lastIndexOf('.');
        if (idx > 0) subs.push(addr.substring(0, idx));
      }
    } catch (_) {
      subs.push('192.168.1');
      subs.push('192.168.0');
    }
    return Array.from(new Set(subs));
  }

  static async scan(port: number = 8080,
                    onProgress?: (done: number, total: number) => void): Promise<DiscoveredServer[]> {
    const subnets = await DiscoveryService.localSubnets();
    const results: DiscoveredServer[] = [];
    let done = 0;
    const total = subnets.length * 254;

    for (const subnet of subnets) {
      const batch: Promise<DiscoveredServer | null>[] = [];
      for (let i = 1; i <= 254; i++) {
        batch.push(DiscoveryService.probe(`${subnet}.${i}`, port));
        if (batch.length >= 64) {
          const r = await Promise.all(batch.splice(0));
          for (const x of r) if (x) results.push(x);
          done += 64;
          onProgress?.(Math.min(done, total), total);
        }
      }
      const r = await Promise.all(batch);
      for (const x of r) if (x) results.push(x);
      done += batch.length;
      onProgress?.(Math.min(done, total), total);
    }
    return results;
  }

  private static probe(ip: string, port: number): Promise<DiscoveredServer | null> {
    return new Promise((resolve) => {
      const r = http.createHttp();
      let settled = false;
      const finish = (v: DiscoveredServer | null) => {
        if (settled) return;
        settled = true;
        try { r.destroy(); } catch (_) {}
        resolve(v);
      };
      const timer = setTimeout(() => finish(null), 400);

      r.request(`http://${ip}:${port}/api/status`, {
        method: http.RequestMethod.GET,
        connectTimeout: 400,
        readTimeout: 400
      }).then((resp) => {
        clearTimeout(timer);
        if (resp.responseCode === 200 || resp.responseCode === 401) {
          finish({ ip, port });
        } else finish(null);
      }).catch(() => {
        clearTimeout(timer);
        finish(null);
      });
    });
  }
}
