import { relationalStore } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { cryptoFramework } from '@kit.CryptoArchitectureKit';

export class DatabaseManager {
  private static store: relationalStore.RdbStore | null = null;

  static async init(ctx: common.Context): Promise<void> {
    const cfg: relationalStore.StoreConfig = {
      name: 'nas_core.db',
      securityLevel: relationalStore.SecurityLevel.S1
    };
    DatabaseManager.store = await relationalStore.getRdbStore(ctx, cfg);
    await DatabaseManager.store.executeSql(
      'CREATE TABLE IF NOT EXISTS users (' +
      'id INTEGER PRIMARY KEY AUTOINCREMENT, ' +
      'username TEXT UNIQUE, password TEXT, role INTEGER, root_dir TEXT)'
    );
    await DatabaseManager.store.executeSql(
      'CREATE TABLE IF NOT EXISTS file_hashes (hash TEXT PRIMARY KEY, path TEXT)'
    );

    const pred = new relationalStore.RdbPredicates('users');
    pred.equalTo('username', 'admin');
    const rs = await DatabaseManager.store.query(pred, ['id']);
    if (rs.rowCount === 0) {
      await DatabaseManager.store.insert('users',
        { username: 'admin', password: 'admin', role: 1, root_dir: '/' });
      await DatabaseManager.store.insert('users',
        { username: 'guest', password: 'guest', role: 2, root_dir: '/Public' });
    }
    rs.close();
  }

  static verifyUser(user: string, pass: string): number {
    if (!DatabaseManager.store) return 0;
    try {
      const pred = new relationalStore.RdbPredicates('users');
      pred.equalTo('username', user).and().equalTo('password', pass);
      const rs = DatabaseManager.store.querySync(pred, ['role']);
      if (rs.goToFirstRow()) {
        const r = rs.getLong(rs.getColumnIndex('role'));
        rs.close();
        return r;
      }
      rs.close();
    } catch (_) {}
    return 0;
  }

  static getUserRoot(user: string): string {
    if (!DatabaseManager.store) return '/';
    try {
      const pred = new relationalStore.RdbPredicates('users');
      pred.equalTo('username', user);
      const rs = DatabaseManager.store.querySync(pred, ['root_dir']);
      if (rs.goToFirstRow()) {
        const v = rs.getString(rs.getColumnIndex('root_dir'));
        rs.close();
        return v;
      }
      rs.close();
    } catch (_) {}
    return '/';
  }

  static saveHash(hash: string, path: string): void {
    try { DatabaseManager.store?.insertSync('file_hashes', { hash, path }); } catch (_) {}
  }

  static getPathByHash(hash: string): string | null {
    if (!DatabaseManager.store) return null;
    try {
      const pred = new relationalStore.RdbPredicates('file_hashes');
      pred.equalTo('hash', hash);
      const rs = DatabaseManager.store.querySync(pred, ['path']);
      if (rs.goToFirstRow()) {
        const v = rs.getString(rs.getColumnIndex('path'));
        rs.close();
        return v;
      }
      rs.close();
    } catch (_) {}
    return null;
  }

  static async md5(input: string): Promise<string> {
    const md = cryptoFramework.createMd('MD5');
    await md.update({ data: new TextEncoder().encode(input) });
    const digest = await md.digest();
    return Array.from(new Uint8Array(digest.data))
      .map(b => b.toString(16).padStart(2, '0')).join('');
  }

  static changePassword(username: string, newPassword: string): void {
    if (!DatabaseManager.store) return;
    try {
      const values: relationalStore.ValuesBucket = { 'password': newPassword };
      const predicates = new relationalStore.RdbPredicates('users');
      predicates.equalTo('username', username);
      DatabaseManager.store.update(values, predicates);
    } catch (e) {}
  }

}
