import '../directory/db.dart';
import 'chat_models.dart';

class GdChatDb {
  GdChatDb._();

  static Future<void> saveMessage(
    String remoteId,
    GdChatDirection direction,
    String sender,
    String text,
  ) async {
    final db = await GdDb.instance;
    await db.insert('chat_messages', {
      'remote_id': remoteId,
      'direction': direction.label,
      'sender': sender,
      'text': text,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  static Future<List<GdChatMessage>> getHistory(
    String remoteId, {
    int limit = 500,
  }) async {
    final db = await GdDb.instance;
    final rows = await db.query(
      'chat_messages',
      where: 'remote_id = ?',
      whereArgs: [remoteId],
      orderBy: 'created_at ASC',
      limit: limit,
    );
    return rows.map(GdChatMessage.fromMap).toList();
  }

  static Future<List<String>> getRemoteIdsWithHistory() async {
    final db = await GdDb.instance;
    final rows = await db.rawQuery(
      'SELECT DISTINCT remote_id FROM chat_messages ORDER BY remote_id ASC',
    );
    return rows.map((r) => r['remote_id'] as String).toList();
  }

  static Future<int> countMessages(String remoteId) async {
    final db = await GdDb.instance;
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM chat_messages WHERE remote_id = ?',
      [remoteId],
    );
    return (rows.first['c'] as int?) ?? 0;
  }

  static Future<void> deleteHistory(String remoteId) async {
    final db = await GdDb.instance;
    await db.delete('chat_messages', where: 'remote_id = ?', whereArgs: [remoteId]);
  }

  static Future<void> deleteOlderThan(DateTime cutoff) async {
    final db = await GdDb.instance;
    await db.delete(
      'chat_messages',
      where: 'created_at < ?',
      whereArgs: [cutoff.toIso8601String()],
    );
  }
}
