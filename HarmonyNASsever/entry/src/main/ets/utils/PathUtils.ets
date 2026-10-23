import { fileIo } from '@kit.CoreFileKit';

export class PathUtils {
  static rootDir: string = '';

  static init(root: string): void { PathUtils.rootDir = root; }

  static resolve(virtualPath: string): string | null {
    let p = virtualPath || '/';
    if (!p.startsWith('/')) p = '/' + p;
    if (p.includes('..')) return null;
    const abs = PathUtils.rootDir + p;
    return abs.startsWith(PathUtils.rootDir) ? abs : null;
  }

  static vpath(abs: string): string {
    return abs.startsWith(PathUtils.rootDir)
      ? (abs.substring(PathUtils.rootDir.length) || '/')
      : '/';
  }

  static exists(abs: string): boolean {
    try { return fileIo.accessSync(abs); } catch (_) { return false; }
  }

  static isDir(abs: string): boolean {
    try { return fileIo.statSync(abs).isDirectory(); } catch (_) { return false; }
  }

  static size(abs: string): number {
    try { return fileIo.statSync(abs).size; } catch (_) { return 0; }
  }

  static mtime(abs: string): number {
    try { return fileIo.statSync(abs).mtime * 1000; } catch (_) { return 0; }
  }
}
