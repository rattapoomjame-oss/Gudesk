/// Pure chat models — no FFI or platform imports so they work in unit tests.
library;

enum GdChatDirection { outgoing, incoming }

extension GdChatDirectionExt on GdChatDirection {
  String get label => name;

  static GdChatDirection fromString(String s) =>
      s == 'outgoing' ? GdChatDirection.outgoing : GdChatDirection.incoming;
}

class GdChatMessage {
  final int? id;
  final String remoteId;
  final GdChatDirection direction;
  final String sender;
  final String text;
  final DateTime createdAt;

  const GdChatMessage({
    this.id,
    required this.remoteId,
    required this.direction,
    required this.sender,
    required this.text,
    required this.createdAt,
  });

  factory GdChatMessage.fromMap(Map<String, dynamic> m) {
    return GdChatMessage(
      id: m['id'] as int?,
      remoteId: m['remote_id'] as String? ?? '',
      direction: GdChatDirectionExt.fromString(m['direction'] as String? ?? 'incoming'),
      sender: m['sender'] as String? ?? '',
      text: m['text'] as String? ?? '',
      createdAt: DateTime.tryParse(m['created_at'] as String? ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'remote_id': remoteId,
        'direction': direction.label,
        'sender': sender,
        'text': text,
        'created_at': createdAt.toIso8601String(),
      };

  bool get isOutgoing => direction == GdChatDirection.outgoing;
}

// ── Export helpers ────────────────────────────────────────────────────────

class GdChatExport {
  /// Plain text transcript, one message per line.
  static String toText(List<GdChatMessage> messages, {String remoteId = ''}) {
    if (messages.isEmpty) return '';
    final header = remoteId.isNotEmpty ? 'Chat with $remoteId\n${'─' * 40}\n' : '';
    final lines = messages.map((m) {
      final ts = _formatTs(m.createdAt);
      final who = m.isOutgoing ? (m.sender.isNotEmpty ? m.sender : 'Me') : remoteId;
      return '[$ts] $who: ${m.text}';
    });
    return '$header${lines.join('\n')}\n';
  }

  /// CSV with header row: id,remote_id,direction,sender,text,created_at
  static String toCsv(List<GdChatMessage> messages) {
    final buf = StringBuffer('id,remote_id,direction,sender,text,created_at\n');
    for (final m in messages) {
      buf.write([
        m.id ?? '',
        _csvField(m.remoteId),
        m.direction.label,
        _csvField(m.sender),
        _csvField(m.text),
        m.createdAt.toIso8601String(),
      ].join(','));
      buf.write('\n');
    }
    return buf.toString();
  }

  static String _csvField(String s) {
    if (s.contains(',') || s.contains('"') || s.contains('\n')) {
      return '"${s.replaceAll('"', '""')}"';
    }
    return s;
  }

  static String _formatTs(DateTime dt) {
    final d = dt.toLocal();
    return '${d.year}-${_pad(d.month)}-${_pad(d.day)} '
        '${_pad(d.hour)}:${_pad(d.minute)}:${_pad(d.second)}';
  }

  static String _pad(int n) => n.toString().padLeft(2, '0');
}
