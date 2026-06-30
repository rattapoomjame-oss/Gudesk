import 'package:sqflite/sqflite.dart';

import '../directory/db.dart';
import 'models.dart';

class GdRecordingDb {
  GdRecordingDb._();

  // ── Sessions ──────────────────────────────────────────────────────────────

  static Future<int> insertSession(GdSession s) async {
    final db = await GdDb.instance;
    return db.insert('sessions', s.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<void> updateSessionEnd(int sessionId, DateTime endTime) async {
    final db = await GdDb.instance;
    await db.update(
      'sessions',
      {'end_time': endTime.toIso8601String(), 'recorded': 1},
      where: 'id = ?',
      whereArgs: [sessionId],
    );
  }

  // ── Recordings ────────────────────────────────────────────────────────────

  /// Inserts a recording. Creates a synthetic session row if [r.sessionId] is null.
  /// Returns 0 (and no-ops) when the filename already exists (unique index guard).
  static Future<int> insertRecording(GdRecording r) async {
    final db = await GdDb.instance;
    final int sId;
    if (r.sessionId != null) {
      sId = r.sessionId!;
    } else {
      sId = await insertSession(GdSession(
        remoteId: r.remoteId,
        startTime: r.createdAt,
        recorded: true,
      ));
    }
    try {
      final map = r.toMap();
      map['session_id'] = sId;
      return await db.insert(
        'recordings',
        map,
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    } catch (_) {
      return 0;
    }
  }

  static Future<List<GdRecording>> getAllRecordings() async {
    final db = await GdDb.instance;
    final rows = await db.query('recordings', orderBy: 'created_at DESC');
    return rows.map(GdRecording.fromMap).toList();
  }

  static Future<void> deleteRecording(int id) async {
    final db = await GdDb.instance;
    await db.delete('recordings', where: 'id = ?', whereArgs: [id]);
  }

  /// Deletes all recording rows with created_at before [cutoff].
  static Future<void> deleteRecordingsBefore(DateTime cutoff) async {
    final db = await GdDb.instance;
    await db.delete(
      'recordings',
      where: 'created_at < ?',
      whereArgs: [cutoff.toIso8601String()],
    );
  }

  static Future<bool> existsByFilename(String filename) async {
    final db = await GdDb.instance;
    final rows = await db.query(
      'recordings',
      columns: ['id'],
      where: 'filename = ?',
      whereArgs: [filename],
      limit: 1,
    );
    return rows.isNotEmpty;
  }
}
