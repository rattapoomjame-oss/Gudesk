import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import 'models.dart';

class GdDb {
  GdDb._();

  static Database? _instance;

  static Future<Database> get instance async {
    _instance ??= await _open();
    return _instance!;
  }

  static Future<Database> _open() async {
    final dir = await _dbDir();
    await dir.create(recursive: true);
    final path = p.join(dir.path, 'gudesk.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  static Future<Directory> _dbDir() async {
    if (Platform.isMacOS) {
      final lib = await getLibraryDirectory();
      return Directory(p.join(lib.path, 'Application Support', 'GuDesk'));
    }
    if (Platform.isWindows) {
      final docs = await getApplicationSupportDirectory();
      return Directory(p.join(docs.path, 'GuDesk'));
    }
    final support = await getApplicationSupportDirectory();
    return Directory(p.join(support.path, 'GuDesk'));
  }

  static Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS directories (
        id         INTEGER PRIMARY KEY AUTOINCREMENT,
        name       TEXT    NOT NULL,
        parent_id  INTEGER REFERENCES directories(id) ON DELETE CASCADE,
        created_at TEXT    NOT NULL DEFAULT (datetime('now')),
        updated_at TEXT    NOT NULL DEFAULT (datetime('now'))
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS devices (
        id           INTEGER PRIMARY KEY AUTOINCREMENT,
        remote_id    TEXT    NOT NULL UNIQUE,
        alias        TEXT,
        directory_id INTEGER REFERENCES directories(id) ON DELETE SET NULL,
        tags         TEXT    NOT NULL DEFAULT '[]',
        notes        TEXT,
        last_seen    TEXT,
        status       TEXT    NOT NULL DEFAULT 'UNKNOWN',
        platform     TEXT,
        version      TEXT,
        color_label  TEXT,
        is_favorite  INTEGER NOT NULL DEFAULT 0,
        is_pinned    INTEGER NOT NULL DEFAULT 0,
        created_at   TEXT    NOT NULL DEFAULT (datetime('now')),
        updated_at   TEXT    NOT NULL DEFAULT (datetime('now'))
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sessions (
        id         INTEGER PRIMARY KEY AUTOINCREMENT,
        remote_id  TEXT NOT NULL,
        start_time TEXT NOT NULL DEFAULT (datetime('now')),
        end_time   TEXT,
        mode       TEXT NOT NULL DEFAULT 'full_access',
        recorded   INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS recordings (
        id         INTEGER PRIMARY KEY AUTOINCREMENT,
        session_id INTEGER NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
        remote_id  TEXT NOT NULL,
        filename   TEXT NOT NULL,
        duration   INTEGER,
        created_at TEXT NOT NULL DEFAULT (datetime('now'))
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_devices_remote   ON devices(remote_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_devices_dir      ON devices(directory_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_sessions_remote  ON sessions(remote_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_recordings_sess  ON recordings(session_id)');
  }

  // ── Directories ──────────────────────────────────────────────────────────

  static Future<int> insertDirectory(GdDirectory d) async {
    final db = await instance;
    final now = DateTime.now().toIso8601String();
    return db.insert('directories', {
      'name': d.name,
      'parent_id': d.parentId,
      'created_at': now,
      'updated_at': now,
    });
  }

  static Future<List<GdDirectory>> getAllDirectories() async {
    final db = await instance;
    final rows = await db.query('directories', orderBy: 'name ASC');
    return rows.map(GdDirectory.fromMap).toList();
  }

  static Future<void> updateDirectory(GdDirectory d) async {
    final db = await instance;
    await db.update(
      'directories',
      {
        'name': d.name,
        'parent_id': d.parentId,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [d.id],
    );
  }

  static Future<void> deleteDirectory(int id) async {
    final db = await instance;
    // Cascade deletes children via FK; devices get NULL directory_id via FK
    await db.delete('directories', where: 'id = ?', whereArgs: [id]);
  }

  // ── Devices ───────────────────────────────────────────────────────────────

  static Future<int> insertDevice(GdDevice d) async {
    final db = await instance;
    final now = DateTime.now().toIso8601String();
    final map = d.toMap();
    map['created_at'] = now;
    map['updated_at'] = now;
    return db.insert('devices', map, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<List<GdDevice>> getAllDevices() async {
    final db = await instance;
    final rows = await db.query('devices', orderBy: 'is_pinned DESC, alias ASC, remote_id ASC');
    return rows.map(GdDevice.fromMap).toList();
  }

  static Future<void> updateDevice(GdDevice d) async {
    final db = await instance;
    final map = d.toMap();
    map['updated_at'] = DateTime.now().toIso8601String();
    map.remove('id');
    await db.update('devices', map, where: 'id = ?', whereArgs: [d.id]);
  }

  static Future<void> deleteDevice(int id) async {
    final db = await instance;
    await db.delete('devices', where: 'id = ?', whereArgs: [id]);
  }

  static Future<void> moveDevice(int deviceId, int? directoryId) async {
    final db = await instance;
    await db.update(
      'devices',
      {'directory_id': directoryId, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [deviceId],
    );
  }

  static Future<void> upsertDeviceStatus(String remoteId, String status) async {
    final db = await instance;
    final now = DateTime.now().toIso8601String();
    await db.rawInsert('''
      INSERT INTO devices (remote_id, status, last_seen, created_at, updated_at)
      VALUES (?, ?, ?, ?, ?)
      ON CONFLICT(remote_id) DO UPDATE SET
        status = excluded.status,
        last_seen = excluded.last_seen,
        updated_at = excluded.updated_at
    ''', [remoteId, status, now, now, now]);
  }
}
