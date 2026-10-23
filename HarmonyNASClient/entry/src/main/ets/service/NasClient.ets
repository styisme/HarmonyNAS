import { http } from '@kit.NetworkKit';
import { AuthStore } from './AuthStore';
import { FileItem, ListResp, StatusInfo, ServerConfig } from '../model/ApiTypes';

export class NasClient {
  private static instance: NasClient | null = null;
  static get(): NasClient {
    if (!NasClient.instance) NasClient.instance = new NasClient();
    return NasClient.instance;
  }

  private cfg: ServerConfig | null = null;

  configure(cfg: ServerConfig): void { this.cfg = cfg; }
  isReady(): boolean { return this.cfg !== null; }
  config(): ServerConfig | null { return this.cfg; }

  private url(path: string): string {
    if (!this.cfg) throw new Error('未配置服务器');
    return AuthStore.baseUrl(this.cfg) + path;
  }

  private auth(): string {
    if (!this.cfg) throw new Error('未配置服务器');
    return AuthStore.toBasic(this.cfg);
  }

  private async req(path: string, method: http.RequestMethod, body?: string,
                     contentType?: string): Promise<string> {
    const r = http.createHttp();
    try {
      const resp = await r.request(this.url(path), {
        method,
        header: {
          'Authorization': this.auth(),
          ...(contentType ? { 'Content-Type': contentType } : {})
        },
        extraData: body,
        connectTimeout: 5000,
        readTimeout: 15000,
        expectDataType: http.HttpDataType.STRING
      });
      if (resp.responseCode >= 200 && resp.responseCode < 300) {
        return resp.result as string;
      }
      throw new Error(`HTTP ${resp.responseCode}`);
    } finally {
      r.destroy();
    }
  }

  async status(): Promise<StatusInfo> {
    return JSON.parse(await this.req('/api/status', http.RequestMethod.GET)) as StatusInfo;
  }

  async list(path: string): Promise<FileItem[]> {
    const res = JSON.parse(await this.req(
      '/api/list?path=' + encodeURIComponent(path), http.RequestMethod.GET)) as ListResp;
    return res.files ?? [];
  }

  async search(q: string): Promise<FileItem[]> {
    return JSON.parse(await this.req(
      '/api/search?q=' + encodeURIComponent(q), http.RequestMethod.GET)) as FileItem[];
  }

  async readText(path: string): Promise<string> {
    return await this.req('/api/preview?path=' + encodeURIComponent(path), http.RequestMethod.GET);
  }

  async saveText(path: string, content: string): Promise<void> {
    await this.req('/api/save', http.RequestMethod.POST,
      `path=${encodeURIComponent(path)}&content=${encodeURIComponent(content)}`,
      'application/x-www-form-urlencoded');
  }

  async mkdir(path: string, name: string): Promise<void> {
    await this.req('/api/mkdir', http.RequestMethod.POST,
      `path=${encodeURIComponent(path)}&name=${encodeURIComponent(name)}`,
      'application/x-www-form-urlencoded');
  }

  async rename(path: string, newName: string): Promise<void> {
    await this.req('/api/rename', http.RequestMethod.POST,
      `path=${encodeURIComponent(path)}&newName=${encodeURIComponent(newName)}`,
      'application/x-www-form-urlencoded');
  }

  async remove(path: string): Promise<void> {
    await this.req('/api/delete', http.RequestMethod.POST,
      `path=${encodeURIComponent(path)}`,
      'application/x-www-form-urlencoded');
  }

  async share(path: string): Promise<string> {
    return await this.req('/api/share', http.RequestMethod.POST,
      `path=${encodeURIComponent(path)}`,
      'application/x-www-form-urlencoded');
  }

  async clipboard(): Promise<string> {
    return await this.req('/api/clipboard', http.RequestMethod.GET);
  }

  async saveClipboard(content: string): Promise<void> {
    await this.req('/api/clipboard', http.RequestMethod.POST,
      `content=${encodeURIComponent(content)}`,
      'application/x-www-form-urlencoded');
  }

  async photos(): Promise<FileItem[]> {
    return JSON.parse(await this.req('/api/photos', http.RequestMethod.GET)) as FileItem[];
  }

  downloadUrl(path: string): string {
    return this.url('/api/download?path=' + encodeURIComponent(path));
  }

  /** 流式 PUT 上传 */
  async upload(path: string, data: ArrayBuffer,
               onProgress?: (pct: number) => void): Promise<void> {
    const r = http.createHttp();
    try {
      const task = r.requestInStream(this.url(path), {
        method: http.RequestMethod.PUT,
        header: {
          'Authorization': this.auth(),
          'Content-Type': 'application/octet-stream',
          'Content-Length': String(data.byteLength)
        },
        extraData: data,
        connectTimeout: 10000,
        readTimeout: 300000
      });
      task.on('dataReceiveProgress', (info: http.DataReceiveProgressInfo) => {
        if (onProgress && info.totalSize > 0) {
          onProgress(Math.floor(info.receiveSize / info.totalSize * 100));
        }
      });
      const code = await task;
      if (code < 200 || code >= 300) throw new Error(`HTTP ${code}`);
    } finally {
      r.destroy();
    }
  }
}
