export interface FileItem {
  name: string;
  dir: boolean;
  size: number;
  path: string;
}

export interface ListResp {
  path: string;
  files: FileItem[];
}

export interface StatusInfo {
  lowPower: boolean;
  clipboardEnabled: boolean;
  globalMode: boolean;
}

export interface ServerConfig {
  host: string;      // 192.168.1.10 或 http://xxx
  port: number;
  user: string;
  pass: string;
  alias: string;
}

export interface PhotoItem {
  name: string;
  path: string;
}

export interface SearchResult {
  name: string;
  path: string;
  dir: boolean;
  size: number;
}

/** 布局决策结果：所有多设备适配从这里出 */
export interface LayoutDecision {
  mode: 'stack' | 'split' | 'grid-full';
  layout: 'list' | 'grid';
  columns: number;
  showFolderTree: boolean;
  focusMode: boolean;       // TV / 手表用
  showBottomTabs: boolean;
  showTopBar: boolean;
}
