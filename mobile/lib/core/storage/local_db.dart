import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Локальное хранилище (local-first): весь игровой цикл работает из SQLite,
/// бэкенд — синхронизация поверх.
class LocalDb {
  final Database db;

  LocalDb._(this.db);

  static Future<LocalDb> open() async {
    final dir = await getDatabasesPath();
    final db = await openDatabase(
      p.join(dir, 'finni.db'),
      version: 1,
      onCreate: (db, version) async {
        await db.execute(
          'CREATE TABLE IF NOT EXISTS kv ('
          'key TEXT PRIMARY KEY, '
          'value TEXT NOT NULL)',
        );
        await db.execute(
          'CREATE TABLE IF NOT EXISTS profile ('
          'id INTEGER PRIMARY KEY CHECK (id = 1), '
          'device_token TEXT NOT NULL, '
          'profile_id TEXT NOT NULL, '
          'display_name TEXT NOT NULL, '
          'link_code TEXT NOT NULL DEFAULT \'\', '
          'state_version INTEGER NOT NULL DEFAULT 0, '
          'pending_remote INTEGER NOT NULL DEFAULT 0, '
          'updated_at TEXT NOT NULL)',
        );
        await db.execute(
          'CREATE TABLE IF NOT EXISTS game_state ('
          'id INTEGER PRIMARY KEY CHECK (id = 1), '
          'json TEXT NOT NULL, '
          'state_version INTEGER NOT NULL DEFAULT 0, '
          'dirty INTEGER NOT NULL DEFAULT 0, '
          'updated_at TEXT NOT NULL)',
        );
        await db.execute(
          'CREATE TABLE IF NOT EXISTS content ('
          'id INTEGER PRIMARY KEY CHECK (id = 1), '
          'version INTEGER NOT NULL, '
          'payload TEXT NOT NULL, '
          'updated_at TEXT NOT NULL)',
        );
      },
    );
    return LocalDb._(db);
  }

  // ---------- kv ----------

  Future<String?> kvGet(String key) async {
    final rows = await db.query('kv', where: 'key = ?', whereArgs: [key], limit: 1);
    if (rows.isEmpty) return null;
    return rows.first['value'] as String?;
  }

  Future<void> kvSet(String key, String value) async {
    await db.insert(
      'kv',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> kvDelete(String key) async {
    await db.delete('kv', where: 'key = ?', whereArgs: [key]);
  }

  /// Полная очистка kv — для деструктивного сброса профиля (ТЗ 2.5.13:
  /// демо-профиль сбрасывается целиком, включая флаги обучалки, дорожки,
  /// ежедневных наград и съеденной еды).
  Future<void> kvClearAll() async {
    await db.delete('kv');
  }

  // ---------- profile ----------

  Future<Map<String, Object?>?> getProfileRow() async {
    final rows = await db.query('profile', where: 'id = 1', limit: 1);
    if (rows.isEmpty) return null;
    return rows.first;
  }

  Future<void> upsertProfile({
    required String deviceToken,
    required String profileId,
    required String displayName,
    required String linkCode,
    required int stateVersion,
    required bool pendingRemote,
  }) async {
    await db.insert(
      'profile',
      {
        'id': 1,
        'device_token': deviceToken,
        'profile_id': profileId,
        'display_name': displayName,
        'link_code': linkCode,
        'state_version': stateVersion,
        'pending_remote': pendingRemote ? 1 : 0,
        'updated_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteProfile() async {
    await db.delete('profile', where: 'id = 1');
  }

  // ---------- game_state ----------

  Future<Map<String, Object?>?> getGameStateRow() async {
    final rows = await db.query('game_state', where: 'id = 1', limit: 1);
    if (rows.isEmpty) return null;
    return rows.first;
  }

  Future<void> upsertGameState({
    required String json,
    required int stateVersion,
    required bool dirty,
  }) async {
    await db.insert(
      'game_state',
      {
        'id': 1,
        'json': json,
        'state_version': stateVersion,
        'dirty': dirty ? 1 : 0,
        'updated_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteGameState() async {
    await db.delete('game_state', where: 'id = 1');
  }

  // ---------- content ----------

  Future<Map<String, Object?>?> getContentRow() async {
    final rows = await db.query('content', where: 'id = 1', limit: 1);
    if (rows.isEmpty) return null;
    return rows.first;
  }

  Future<void> upsertContent({
    required int version,
    required String payload,
  }) async {
    await db.insert(
      'content',
      {
        'id': 1,
        'version': version,
        'payload': payload,
        'updated_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
