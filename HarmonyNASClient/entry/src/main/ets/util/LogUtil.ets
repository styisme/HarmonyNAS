const MAX = 200;

export class LogManager {
  private static logs: string[] = [];

  static add(tag: string, msg: string): void {
    const t = new Date().toTimeString().substring(0, 8);
    this.logs.unshift(`[${t}] ${tag} - ${msg}`);
    if (this.logs.length > MAX) this.logs.pop();
  }

  static getAll(): string {
    return this.logs.length === 0 ? '暂无日志' : this.logs.join('\n');
  }
}
