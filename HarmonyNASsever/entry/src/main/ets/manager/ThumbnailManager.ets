import { image } from '@kit.ImageKit';
import { fileIo } from '@kit.CoreFileKit';
import { PathUtils } from '../utils/PathUtils';
import { LogManager } from './LogManager';

export class ThumbnailManager {
  private static THUMB_DIR_NAME = '/.thumbnails';
  private static TARGET_SIZE = 300;

  static async get(absPath: string): Promise<string> {
    try {
      const thumbDir = PathUtils.rootDir + ThumbnailManager.THUMB_DIR_NAME;
      if (!PathUtils.exists(thumbDir)) fileIo.mkdirSync(thumbDir, true);

      const vp = PathUtils.vpath(absPath);
      const safeName = vp.replace(/^\//, '').replace(/\//g, '_');
      const thumbPath = thumbDir + '/' + safeName + '.jpg';

      const srcMtime = PathUtils.mtime(absPath);
      if (PathUtils.exists(thumbPath) && PathUtils.mtime(thumbPath) >= srcMtime) {
        return thumbPath;
      }

      const srcFile = fileIo.openSync(absPath, fileIo.OpenMode.READ_ONLY);
      const src = image.createImageSource(srcFile.fd);
      const opts: image.InitializationOptions = {
        size: { width: ThumbnailManager.TARGET_SIZE, height: ThumbnailManager.TARGET_SIZE }
      };
      const pixelMap = await src.createPixelMap(opts);
      const packer = image.createImagePacker();
      const buf = await packer.packing(pixelMap, { format: 'image/jpeg', quality: 80 });

      const out = fileIo.openSync(thumbPath,
        fileIo.OpenMode.CREATE | fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.TRUNC);
      fileIo.writeSync(out.fd, buf);
      fileIo.closeSync(out);
      fileIo.closeSync(srcFile);
      return thumbPath;
    } catch (e) {
      LogManager.add('THUMB', '生成失败: ' + (e as Error).message);
      return absPath;
    }
  }
}
