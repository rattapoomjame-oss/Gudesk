import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_hbb/gudesk/chat/chat_models.dart';

void main() {
  // ── GdChatDirection ───────────────────────────────────────────────────────

  group('GdChatDirection', () {
    test('outgoing label is "outgoing"', () {
      expect(GdChatDirection.outgoing.label, 'outgoing');
    });

    test('incoming label is "incoming"', () {
      expect(GdChatDirection.incoming.label, 'incoming');
    });

    test('fromString parses "outgoing"', () {
      expect(GdChatDirectionExt.fromString('outgoing'), GdChatDirection.outgoing);
    });

    test('fromString parses "incoming"', () {
      expect(GdChatDirectionExt.fromString('incoming'), GdChatDirection.incoming);
    });

    test('fromString defaults to incoming for unknown value', () {
      expect(GdChatDirectionExt.fromString('???'), GdChatDirection.incoming);
    });
  });

  // ── GdChatMessage.fromMap ─────────────────────────────────────────────────

  group('GdChatMessage.fromMap', () {
    test('round-trips via toMap/fromMap', () {
      final ts = DateTime(2026, 6, 30, 14, 0, 0);
      final m = GdChatMessage(
        id: 1,
        remoteId: 'peer-001',
        direction: GdChatDirection.outgoing,
        sender: 'Alice',
        text: 'Hello!',
        createdAt: ts,
      );
      final m2 = GdChatMessage.fromMap(m.toMap());
      expect(m2.id, 1);
      expect(m2.remoteId, 'peer-001');
      expect(m2.direction, GdChatDirection.outgoing);
      expect(m2.sender, 'Alice');
      expect(m2.text, 'Hello!');
      expect(m2.createdAt, ts);
    });

    test('handles missing id', () {
      final m = GdChatMessage.fromMap({
        'remote_id': 'x',
        'direction': 'incoming',
        'sender': '',
        'text': 'hi',
        'created_at': '2026-01-01T00:00:00.000',
      });
      expect(m.id, isNull);
      expect(m.direction, GdChatDirection.incoming);
    });

    test('handles missing fields with defaults', () {
      final m = GdChatMessage.fromMap({});
      expect(m.remoteId, '');
      expect(m.direction, GdChatDirection.incoming);
      expect(m.sender, '');
      expect(m.text, '');
    });

    test('toMap omits id when null', () {
      final m = GdChatMessage(
        remoteId: 'r',
        direction: GdChatDirection.incoming,
        sender: '',
        text: 'test',
        createdAt: DateTime(2026),
      );
      expect(m.toMap().containsKey('id'), isFalse);
    });

    test('isOutgoing returns true for outgoing direction', () {
      final m = GdChatMessage(
        remoteId: 'r',
        direction: GdChatDirection.outgoing,
        sender: 'Me',
        text: 'hey',
        createdAt: DateTime(2026),
      );
      expect(m.isOutgoing, isTrue);
    });

    test('isOutgoing returns false for incoming direction', () {
      final m = GdChatMessage(
        remoteId: 'r',
        direction: GdChatDirection.incoming,
        sender: '',
        text: 'hey',
        createdAt: DateTime(2026),
      );
      expect(m.isOutgoing, isFalse);
    });
  });

  // ── GdChatExport.toText ───────────────────────────────────────────────────

  GdChatMessage _msg({
    required GdChatDirection direction,
    String sender = '',
    required String text,
    DateTime? at,
  }) {
    return GdChatMessage(
      remoteId: 'peer-001',
      direction: direction,
      sender: sender,
      text: text,
      createdAt: at ?? DateTime(2026, 6, 30, 10, 0, 0),
    );
  }

  group('GdChatExport.toText', () {
    test('returns empty string for empty list', () {
      expect(GdChatExport.toText([]), '');
    });

    test('includes header when remoteId provided', () {
      final msgs = [
        _msg(direction: GdChatDirection.outgoing, sender: 'Alice', text: 'Hi'),
      ];
      final out = GdChatExport.toText(msgs, remoteId: 'PEER-001');
      expect(out, contains('Chat with PEER-001'));
    });

    test('formats outgoing message with sender name', () {
      final msgs = [
        _msg(direction: GdChatDirection.outgoing, sender: 'Bob', text: 'Hello'),
      ];
      final out = GdChatExport.toText(msgs, remoteId: 'peer');
      expect(out, contains('Bob: Hello'));
    });

    test('uses "Me" when outgoing sender is empty', () {
      final msgs = [
        _msg(direction: GdChatDirection.outgoing, sender: '', text: 'Hi there'),
      ];
      final out = GdChatExport.toText(msgs);
      expect(out, contains('Me: Hi there'));
    });

    test('formats incoming message with remoteId as sender', () {
      final msgs = [
        _msg(direction: GdChatDirection.incoming, text: 'Reply'),
      ];
      final out = GdChatExport.toText(msgs, remoteId: 'remote-host');
      expect(out, contains('remote-host: Reply'));
    });

    test('includes timestamp in output', () {
      final ts = DateTime(2026, 6, 30, 14, 30, 5);
      final msgs = [
        _msg(direction: GdChatDirection.outgoing, sender: 'X', text: 'msg', at: ts),
      ];
      final out = GdChatExport.toText(msgs);
      expect(out, contains('2026-06-30'));
      expect(out, contains('14:30:05'));
    });

    test('multiple messages each on own line', () {
      final msgs = [
        _msg(direction: GdChatDirection.outgoing, sender: 'A', text: 'first'),
        _msg(direction: GdChatDirection.incoming, text: 'second'),
      ];
      final out = GdChatExport.toText(msgs, remoteId: 'R');
      final lines = out.trim().split('\n');
      expect(lines.where((l) => l.contains(': ')).length, greaterThanOrEqualTo(2));
    });
  });

  // ── GdChatExport.toCsv ────────────────────────────────────────────────────

  group('GdChatExport.toCsv', () {
    test('returns header-only for empty list', () {
      final csv = GdChatExport.toCsv([]);
      expect(csv.trim(), 'id,remote_id,direction,sender,text,created_at');
    });

    test('produces correct column count per row', () {
      final msgs = [
        _msg(direction: GdChatDirection.outgoing, sender: 'Alice', text: 'Hi'),
      ];
      final lines = GdChatExport.toCsv(msgs).trim().split('\n');
      expect(lines.length, 2);
      expect(lines[1].split(',').length, greaterThanOrEqualTo(5));
    });

    test('escapes commas in text', () {
      final msgs = [
        _msg(direction: GdChatDirection.outgoing, sender: 'A', text: 'hello, world'),
      ];
      final csv = GdChatExport.toCsv(msgs);
      expect(csv, contains('"hello, world"'));
    });

    test('escapes double-quotes in text', () {
      final msgs = [
        _msg(direction: GdChatDirection.outgoing, sender: 'A', text: 'say "hi"'),
      ];
      final csv = GdChatExport.toCsv(msgs);
      expect(csv, contains('say ""hi""'));
    });

    test('direction column matches label', () {
      final msgs = [
        _msg(direction: GdChatDirection.incoming, text: 'x'),
      ];
      final csv = GdChatExport.toCsv(msgs);
      expect(csv, contains('incoming'));
    });
  });
}
