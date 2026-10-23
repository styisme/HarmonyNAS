import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { fileIo } from '@kit.CoreFileKit';
import { common } from '@kit.AbilityKit';
import { NasClient } from './NasClient';
import { FileItem } from '../model/ApiTypes';
import { LogManager } from '../util/LogUtil';

export interface BackupResult {
  uploaded: number;
  skipped: number;
  failed: number;
}

/**
 * 相册增量备份：
 * 1. 拉取服务端 /Photos 列表
 * 2. 遍历本地相册（photoAccessHelper），跳过同名
 * 3. 逐个流式 PUT 上传到 /Photos/{name}
 */
export class BackupService {
  static async run(ctx: common.Context,
                   onProgress?: (done: number, total: number, name: string) => void): Promise<BackupResult> {
    const result: BackupResult = { uploaded: 0, skipped: 0, failed: 0 };
    const nas = NasClient.get();
    if (!nas.isReady()) throw new Error('未配置服务器');

    // 服务端已有
    let remote: FileItem[] = [];
    try { remote = await nas.list('/Photos'); } catch (_) { /* 目录不存在 */ }
    const remoteNames = new Set(remote.filter(f => !f.dir).map(f => f.name));

    // 本地相册
    const helper = photoAccessHelper.getPhotoAccessHelper(ctx);
    const fetchOptions: photoAccessHelper.FetchOptions = {
      fetchColumns: ['display_name', 'uri', 'size'],
      predicates: new photoAccessHelper.DataSharePredicates()
    };
    const assets = await helper.getAssets(fetchOptions);
    const total = assets.length;

    let i = 0;
    while (assets.hasNext()) {
      i++;
      const asset = assets.getNext();
      const name = (asset.displayName as string) || `photo_${Date.now()}.jpg`;
      onProgress?.(i, total, name);

      if (remoteNames.has(name)) { result.skipped++; continue; }

      try {
        const src = await asset.open('r');
        const buf = new ArrayBuffer(asset.size as number ?? 0);
        const n = src.readSync(buf);
        src.close();
        if (n <= 0) { result.failed++; continue; }
        await nas.upload('/Photos/' + encodeURIComponent(name), buf.slice(0, n));
        remoteNames.add(name);
        result.uploaded++;
      } catch (e) {
        LogManager.add('BACKUP', `上传失败 ${name}: ${(e as Error).message}`);
        result.failed++;
      }
    }
    assets.close();
    return result;
  }
}
