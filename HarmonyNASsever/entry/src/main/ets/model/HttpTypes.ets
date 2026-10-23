export interface HttpRequest {
  method: string;
  uri: string;
  query: Record<string, string>;
  headers: Record<string, string>;
  body: ArrayBuffer;
}

export interface StreamFile {
  fd: number;
  size: number;
  mime: string;
  name?: string;
  rangeStart?: number;
  rangeEnd?: number;
}

export interface HttpResponse {
  status: number;
  headers?: Record<string, string>;
  body?: ArrayBuffer | string;
  streamFile?: StreamFile;
}

export type RequestHandler = (req: HttpRequest) => Promise<HttpResponse>;
