import { HttpRequest, HttpResponse } from '../model/HttpTypes';

export function findHeaderEnd(buf: Uint8Array): number {
  for (let i = 0; i < buf.length - 3; i++) {
    if (buf[i] === 13 && buf[i + 1] === 10 && buf[i + 2] === 13 && buf[i + 3] === 10) return i;
  }
  return -1;
}

export function parseHeaders(raw: string): HttpRequest {
  const lines = raw.split('\r\n');
  const [method, fullUri] = lines[0].split(' ');
  const qIdx = fullUri.indexOf('?');
  const uri = qIdx >= 0 ? fullUri.substring(0, qIdx) : fullUri;
  const query: Record<string, string> = {};
  if (qIdx >= 0) {
    for (const kv of fullUri.substring(qIdx + 1).split('&')) {
      const [k, v] = kv.split('=');
      if (k) query[decodeURIComponent(k)] = decodeURIComponent(v ?? '');
    }
  }
  const headers: Record<string, string> = {};
  for (let i = 1; i < lines.length; i++) {
    const idx = lines[i].indexOf(':');
    if (idx > 0) {
      headers[lines[i].substring(0, idx).trim().toLowerCase()] =
        lines[i].substring(idx + 1).trim();
    }
  }
  return { method, uri, query, headers, body: new ArrayBuffer(0) };
}

export function jsonResponse(obj: Object): HttpResponse {
  return {
    status: 200,
    headers: { 'Content-Type': 'application/json; charset=utf-8' },
    body: JSON.stringify(obj)
  };
}

export function textResponse(code: number, msg: string): HttpResponse {
  return {
    status: code,
    headers: { 'Content-Type': 'text/plain; charset=utf-8' },
    body: msg
  };
}

export function parseBodyParams(req: HttpRequest): Record<string, string> {
  const ct = (req.headers['content-type'] ?? '').toLowerCase();
  const text = new TextDecoder().decode(new Uint8Array(req.body));
  const out: Record<string, string> = {};
  if (ct.includes('application/json')) {
    try {
      const o = JSON.parse(text) as Record<string, string>;
      for (const k of Object.keys(o)) out[k] = String(o[k]);
    } catch (_) {}
  } else if (ct.includes('x-www-form-urlencoded') || !ct) {
    for (const kv of text.split('&')) {
      const i = kv.indexOf('=');
      if (i > 0) {
        out[decodeURIComponent(kv.substring(0, i))] =
          decodeURIComponent(kv.substring(i + 1).replace(/\+/g, ' '));
      }
    }
  }
  return out;
}

export function concatUint8(a: Uint8Array, b: Uint8Array): Uint8Array {
  const out = new Uint8Array(a.length + b.length);
  out.set(a); out.set(b, a.length);
  return out;
}

export function guessMime(p: string): string {
  const l = p.toLowerCase();
  if (l.endsWith('.mp4')) return 'video/mp4';
  if (l.endsWith('.webm')) return 'video/webm';
  if (l.endsWith('.mkv')) return 'video/x-matroska';
  if (l.endsWith('.mp3')) return 'audio/mpeg';
  if (l.endsWith('.wav')) return 'audio/wav';
  if (l.endsWith('.jpg') || l.endsWith('.jpeg')) return 'image/jpeg';
  if (l.endsWith('.png')) return 'image/png';
  if (l.endsWith('.gif')) return 'image/gif';
  if (l.endsWith('.webp')) return 'image/webp';
  if (l.endsWith('.txt')) return 'text/plain; charset=utf-8';
  if (l.endsWith('.html')) return 'text/html; charset=utf-8';
  if (l.endsWith('.json')) return 'application/json; charset=utf-8';
  return 'application/octet-stream';
}


export interface MultipartFile {
  name: string;
  filename: string;
  data: Uint8Array;
}

export interface MultipartResult {
  fields: Record<string, string>;
  files: MultipartFile[];
}

export function parseMultipart(req: HttpRequest): MultipartResult {
  const result: MultipartResult = { fields: {}, files: [] };
  const ct = req.headers['content-type'] ?? '';
  const match = ct.match(/boundary=(.+)$/);
  if (!match) return result;

  const boundary = '--' + match[1];
  const body = new Uint8Array(req.body);
  
  let binaryStr = '';
  for (let i = 0; i < body.length; i++) {
    binaryStr += String.fromCharCode(body[i]);
  }

  const parts = binaryStr.split(boundary);
  for (let i = 1; i < parts.length - 1; i++) {
    const part = parts[i];
    const headerEnd = part.indexOf('\r\n\r\n');
    if (headerEnd < 0) continue;
    
    const headerStr = part.substring(0, headerEnd);
    const dataStr = part.substring(headerEnd + 4, part.length - 2);
    
    let name = '';
    let filename = '';
    const nameMatch = headerStr.match(/name="([^"]+)"/);
    if (nameMatch) name = nameMatch[1];
    const filenameMatch = headerStr.match(/filename="([^"]+)"/);
    if (filenameMatch) filename = filenameMatch[1];

    if (filename) {
      const data = new Uint8Array(dataStr.length);
      for (let j = 0; j < dataStr.length; j++) {
        data[j] = dataStr.charCodeAt(j);
      }
      result.files.push({ name, filename, data });
    } else if (name) {
      result.fields[name] = dataStr;
    }
  }
  return result;
}
