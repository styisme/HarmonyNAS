import { fileIo } from '@kit.CoreFileKit';
import { zlib } from '@kit.BasicServicesKit';
import { common } from '@kit.AbilityKit';
import { HttpRequest, HttpResponse } from '../model/HttpTypes';
import { PathUtils } from '../utils/PathUtils';
import { jsonResponse, textResponse, parseBodyParams, parseMultipart, guessMime } from '../utils/HttpUtils';
import { AuthManager } from '../manager/AuthManager';
import { SettingsManager } from '../manager/SettingsManager';
import { DatabaseManager } from '../manager/DatabaseManager';
import { AdManager } from '../manager/AdManager';
import { VersionManager } from '../manager/VersionManager';
import { ThumbnailManager } from '../manager/ThumbnailManager';
import { AdSlot } from '../model/AdTypes';
import { LogManager } from '../manager/LogManager';

const shareMap = new Map<string, string>();
let clipboard = '';

export class NasApiRouter {
  static ctx: common.Context;

  async handle(req: HttpRequest): Promise<HttpResponse> {
    if (req.method !== 'OPTIONS' && !req.uri.startsWith('/share/') && !req.uri.startsWith('/ads/')) {
      if (!AuthManager.verify(req.headers['authorization'])) {
        return { status: 401, headers: { 'WWW-Authenticate': 'Basic realm="Harmony NAS"' }, body: '401' };
      }
    }

    const p = req.query;

    if (req.uri === '/api/list') {
      const vp = p['path'] ?? '/';
      const abs = PathUtils.resolve(vp);
      if (!abs || !PathUtils.isDir(abs)) return textResponse(404, 'Not found');
      const files = fileIo.listFileSync(abs).map(n => {
        const fp = abs + (abs.endsWith('/') ? '' : '/') + n;
        const st = fileIo.statSync(fp);
        return { name: n, dir: st.isDirectory(), size: st.size, path: PathUtils.vpath(fp) };
      });
      return jsonResponse({ path: vp, files });
    }

    if (req.uri === '/api/download') {
      const abs = PathUtils.resolve(p['path'] ?? '');
      if (!abs || !PathUtils.exists(abs) || PathUtils.isDir(abs)) return textResponse(404, 'Not found');
      const size = PathUtils.size(abs);
      const fd = fileIo.openSync(abs, fileIo.OpenMode.READ_ONLY);
      const range = req.headers['range'];
      if (range) {
        const m = /bytes=(\d+)-(\d*)/.exec(range);
        if (m) {
          return { status: 206, streamFile: {
            fd, size, mime: guessMime(abs),
            rangeStart: parseInt(m[1]),
            rangeEnd: m[2] ? parseInt(m[2]) : size - 1,
            name: basename(abs)
          }};
        }
      }
      return { status: 200, streamFile: { fd, size, mime: guessMime(abs), name: basename(abs) } };
    }

    if (req.method === 'PUT') {
      const abs = PathUtils.resolve(req.uri);
      if (!abs) return textResponse(403, 'Path invalid');
      ensureDir(abs.substring(0, abs.lastIndexOf('/')));
      const f = fileIo.openSync(abs, fileIo.OpenMode.CREATE | fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.TRUNC);
      fileIo.writeSync(f.fd, req.body);
      fileIo.closeSync(f);
      return textResponse(200, 'OK');
    }

    if (req.uri === '/api/upload' && req.method === 'POST') {
      const mp = parseMultipart(req);
      const targetPath = mp.fields['path'] || '/';
      const baseAbs = PathUtils.resolve(targetPath);
      if (!baseAbs || !PathUtils.isDir(baseAbs)) return textResponse(400, 'Invalid path');

      let saved = [];
      for (const f of mp.files) {
        if (!isSafeName(f.filename)) continue;
        const abs = baseAbs + (baseAbs.endsWith('/') ? '' : '/') + f.filename;
        const file = fileIo.openSync(abs, fileIo.OpenMode.CREATE | fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.TRUNC);
        fileIo.writeSync(file.fd, f.data.buffer);
        fileIo.closeSync(file);
        saved.push(f.filename);
      }
      return textResponse(200, `OK: ${saved.join(', ')}`);
    }

    if (req.uri === '/api/preview') {
      const abs = PathUtils.resolve(p['path'] ?? '');
      if (!abs || !PathUtils.exists(abs)) return textResponse(404, 'Not found');
      if (PathUtils.size(abs) > 2 * 1024 * 1024) return textResponse(400, 'File too large');
      const f = fileIo.openSync(abs, fileIo.OpenMode.READ_ONLY);
      const buf = new ArrayBuffer(PathUtils.size(abs));
      fileIo.readSync(f.fd, buf);
      fileIo.closeSync(f);
      return { status: 200, headers: { 'Content-Type': 'text/plain; charset=utf-8' }, body: buf };
    }

    if (req.uri === '/api/mkdir' && req.method === 'POST') {
      const b = parseBodyParams(req);
      const name = b['name'] ?? '';
      if (!isSafeName(name)) return textResponse(400, 'Bad name');
      const abs = PathUtils.resolve((b['path'] ?? '/') + '/' + name);
      if (!abs) return textResponse(400, 'Bad path');
      fileIo.mkdirSync(abs, true);
      return textResponse(200, 'OK');
    }

    if (req.uri === '/api/rename' && req.method === 'POST') {
      const b = parseBodyParams(req);
      const abs = PathUtils.resolve(b['path'] ?? '');
      const newName = b['newName'] ?? '';
      if (!abs || !isSafeName(newName)) return textResponse(400, 'Bad');
      fileIo.renameSync(abs, abs.substring(0, abs.lastIndexOf('/') + 1) + newName);
      return textResponse(200, 'OK');
    }

    if (req.uri === '/api/delete' && req.method === 'POST') {
      const abs = PathUtils.resolve(parseBodyParams(req)['path'] ?? '');
      if (!abs || abs === PathUtils.rootDir) return textResponse(400, 'Bad');
      fileIo.rmdirSync(abs);
      return textResponse(200, 'OK');
    }

    if (req.uri === '/api/save' && req.method === 'POST') {
      const b = parseBodyParams(req);
      const abs = PathUtils.resolve(b['path'] ?? '');
      if (!abs) return textResponse(400, 'Bad');
      const f = fileIo.openSync(abs, fileIo.OpenMode.CREATE | fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.TRUNC);
      fileIo.writeSync(f.fd, new TextEncoder().encode(b['content'] ?? ''));
      fileIo.closeSync(f);
      return textResponse(200, 'OK');
    }

    if (req.uri === '/api/unzip' && req.method === 'POST') {
      const b = parseBodyParams(req);
      const abs = PathUtils.resolve(b['path'] ?? '');
      if (!abs || !PathUtils.exists(abs) || !abs.toLowerCase().endsWith('.zip')) {
        return textResponse(400, 'Not a zip file');
      }
      const destDir = abs.substring(0, abs.lastIndexOf('.'));
      if (!PathUtils.exists(destDir)) fileIo.mkdirSync(destDir, true);

      try {
        const options: zlib.Options = { level: zlib.CompressLevel.COMPRESS_LEVEL_DEFAULT_COMPRESSION };
        await zlib.decompressFile(abs, destDir, options);
        return textResponse(200, 'OK');
      } catch (e) {
        LogManager.add('UNZIP', '解压失败: ' + (e as Error).message);
        return textResponse(500, 'Unzip failed');
      }
    }

    if (req.uri === '/api/password' && req.method === 'POST') {
      const b = parseBodyParams(req);
      const pwd = b['password'] ?? '';
      if (pwd.length < 1) return textResponse(400, 'Password required');
      DatabaseManager.changePassword(AuthManager.getCurrentUser(), pwd);
      return textResponse(200, 'OK');
    }

    if (req.uri === '/api/share' && req.method === 'POST') {
      const abs = PathUtils.resolve(parseBodyParams(req)['path'] ?? '');
      if (!abs || !PathUtils.exists(abs)) return textResponse(404, 'Not found');
      const token = Math.random().toString(36).substring(2, 10);
      shareMap.set(token, abs);
      return textResponse(200, token);
    }
    if (req.uri.startsWith('/share/')) {
      const abs = shareMap.get(req.uri.substring(7));
      if (!abs || !PathUtils.exists(abs)) return textResponse(404, 'Share expired');
      return { status: 200, streamFile: {
        fd: fileIo.openSync(abs, fileIo.OpenMode.READ_ONLY),
        size: PathUtils.size(abs), mime: guessMime(abs), name: basename(abs)
      }};
    }

    if (req.uri === '/api/search') {
      const q = (p['q'] ?? '').toLowerCase();
      const out: object[] = [];
      searchRec(PathUtils.rootDir, q, out, 0);
      return jsonResponse(out);
    }

    if (req.uri === '/api/clipboard') {
      if (req.method === 'POST') {
        clipboard = parseBodyParams(req)['content'] ?? '';
        return textResponse(200, 'OK');
      }
      return textResponse(200, clipboard);
    }

    if (req.uri === '/api/status') {
      return jsonResponse({
        lowPower: false,
        clipboardEnabled: SettingsManager.isClipboardEnabled(),
        globalMode: false
      });
    }

    if (req.uri === '/api/settings') {
      if (req.method === 'POST') {
        const b = parseBodyParams(req);
        if (b['alias']) SettingsManager.setDeviceAlias(b['alias']);
        if (b['webPort']) SettingsManager.setWebPort(parseInt(b['webPort']));
        if (b['davPort']) SettingsManager.setWebDavPort(parseInt(b['davPort']));
        if (b['ftpPort']) SettingsManager.setFtpPort(parseInt(b['ftpPort']));
        if (b['webdav'] !== undefined) SettingsManager.setWebDavEnabled(b['webdav'] === 'true');
        if (b['ftp'] !== undefined) SettingsManager.setFtpEnabled(b['ftp'] === 'true');
        if (b['dlna'] !== undefined) SettingsManager.setDlnaEnabled(b['dlna'] === 'true');
        if (b['clipboard'] !== undefined) SettingsManager.setClipboardEnabled(b['clipboard'] === 'true');
        if (b['adsEnabled'] !== undefined) SettingsManager.setAdsEnabled(b['adsEnabled'] === 'true');
        return textResponse(200, 'OK');
      }
      return jsonResponse({
        alias: SettingsManager.getDeviceAlias(),
        webPort: SettingsManager.getWebPort(),
        davPort: SettingsManager.getWebDavPort(),
        ftpPort: SettingsManager.getFtpPort(),
        webdav: SettingsManager.isWebDavEnabled(),
        ftp: SettingsManager.isFtpEnabled(),
        dlna: SettingsManager.isDlnaEnabled(),
        clipboard: SettingsManager.isClipboardEnabled(),
        adsEnabled: SettingsManager.isAdsEnabled()
      });
    }

    if (req.uri === '/api/ads' && req.method === 'GET') {
      const slot = (p['slot'] ?? 'fileListBottom') as AdSlot;
      const ads = await AdManager.getAds(slot, parseInt(p['count'] ?? '1'));
      return jsonResponse({
        enabled: AdManager.isEnabled(),
        refreshIntervalSec: AdManager.getRefreshInterval(),
        ads
      });
    }
    if (req.uri === '/api/ads/impression' || req.uri === '/api/ads/click') {
      const b = req.method === 'POST' ? parseBodyParams(req) : p;
      const adId = b['adId'] ?? '';
      const slot = (b['slot'] ?? '') as AdSlot;
      if (!adId || !slot) return textResponse(400, 'Bad');
      AdManager.track({
        adId, slot,
        type: req.uri.endsWith('click') ? 'click' : 'impression',
        ts: Date.now(), user: AuthManager.getCurrentUser()
      });
      return textResponse(200, 'OK');
    }

    if (req.uri === '/api/ota') {
      const v = VersionManager.get();
      return jsonResponse({
        versionName: v.versionName, versionCode: v.versionCode,
        buildDate: v.buildDate, channel: v.channel
      });
    }

    if (req.uri === '/api/upload/check') {
      const hash = p['hash'] ?? '';
      return textResponse(200, DatabaseManager.getPathByHash(hash) ? 'SECONDS_UPLOAD' : 'NEED_UPLOAD');
    }
    if (req.uri === '/api/upload/merge' && req.method === 'POST') {
      const b = parseBodyParams(req);
      DatabaseManager.saveHash(b['hash'] ?? '', b['path'] ?? '');
      return textResponse(200, 'OK');
    }

    if (req.uri === '/api/thumb') {
      const abs = PathUtils.resolve(p['path'] ?? '');
      if (!abs || !PathUtils.exists(abs)) return textResponse(404, 'Not found');
      const thumb = await ThumbnailManager.get(abs);
      return { status: 200, streamFile: {
        fd: fileIo.openSync(thumb, fileIo.OpenMode.READ_ONLY),
        size: PathUtils.size(thumb), mime: 'image/jpeg'
      }};
    }

    if (req.uri === '/api/photos') {
      const photos: { name: string; path: string }[] = [];
      scanPhotos(PathUtils.rootDir, photos, 0);
      return jsonResponse(photos);
    }

    if (req.uri.startsWith('/ads/')) {
      const name = req.uri.substring(5);
      if (!/^[\w.\-]+$/.test(name)) return textResponse(400, 'Bad name');
      try {
        const raw = await NasApiRouter.ctx.resourceManager.getRawFileContent('ads/' + name);
        return { status: 200, headers: { 'Content-Type': guessMime(name) }, body: raw.buffer };
      } catch (_) {
        return textResponse(404, 'Not found');
      }
    }

    if (req.uri === '/' || req.uri === '/index.html') {
      const raw = await NasApiRouter.ctx.resourceManager.getRawFileContent('index.html');
      return { status: 200, headers: { 'Content-Type': 'text/html; charset=utf-8' }, body: raw.buffer };
    }

    return textResponse(404, 'Not found');
  }
}

function isSafeName(n: string): boolean {
  return !!n && !n.includes('/') && !n.includes('\\') && n !== '.' && n !== '..';
}
function basename(abs: string): string { return abs.substring(abs.lastIndexOf('/') + 1); }
function ensureDir(dir: string): void {
  if (dir && !PathUtils.exists(dir)) fileIo.mkdirSync(dir, true);
}
function searchRec(dir: string, q: string, out: object[], depth: number): void {
  if (depth > 6 || out.length > 500) return;
  try {
    for (const name of fileIo.listFileSync(dir)) {
      const fp = dir + '/' + name;
      const st = fileIo.statSync(fp);
      if (st.isDirectory()) searchRec(fp, q, out, depth + 1);
      else if (name.toLowerCase().includes(q)) {
        out.push({ name, path: PathUtils.vpath(fp), dir: false, size: st.size });
      }
    }
  } catch (_) {}
}
function scanPhotos(dir: string, out: { name: string; path: string }[], depth: number): void {
  if (depth > 5 || out.length > 1000) return;
  try {
    for (const name of fileIo.listFileSync(dir)) {
      const fp = dir + '/' + name;
      const st = fileIo.statSync(fp);
      if (st.isDirectory()) {
        if (!name.startsWith('.')) scanPhotos(fp, out, depth + 1);
      } else {
        const l = name.toLowerCase();
        if (l.endsWith('.jpg') || l.endsWith('.jpeg') || l.endsWith('.png')) {
          out.push({ name, path: PathUtils.vpath(fp) });
        }
      }
    }
  } catch (_) {}
}
