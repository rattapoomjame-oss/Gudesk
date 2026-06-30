import 'dart:io';
import 'package:path/path.dart' as p;

// Pattern: (outgoing|incoming)_<remoteId>_<YYYYMMDDHHmmSSmmm>_(display|camera)<N>_<codec>.(mp4|webm)
// chrono format string: _%Y%m%d%H%M%S%3f_  → 17-char datetime token
final _kFilenameRe = RegExp(
  r'^(outgoing|incoming)_(.+?)_(\d{17})_(display|camera)(\d+)_([^.]+)\.(mp4|webm)$',
);

class GdSession {
  final int? id;
  final String remoteId;
  final DateTime startTime;
  final DateTime? endTime;
  final String mode;
  final bool recorded;

  const GdSession({
    this.id,
    required this.remoteId,
    required this.startTime,
    this.endTime,
    this.mode = 'full_access',
    this.recorded = false,
  });

  Duration? get duration =>
      endTime != null ? endTime!.difference(startTime) : null;

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'remote_id': remoteId,
        'start_time': startTime.toIso8601String(),
        'end_time': endTime?.toIso8601String(),
        'mode': mode,
        'recorded': recorded ? 1 : 0,
      };

  factory GdSession.fromMap(Map<String, dynamic> map) => GdSession(
        id: map['id'] as int?,
        remoteId: map['remote_id'] as String,
        startTime: DateTime.parse(map['start_time'] as String),
        endTime: map['end_time'] != null
            ? DateTime.parse(map['end_time'] as String)
            : null,
        mode: map['mode'] as String? ?? 'full_access',
        recorded: (map['recorded'] as int? ?? 0) != 0,
      );
}

class GdRecording {
  final int? id;
  final int? sessionId;
  final String remoteId;
  final String filename; // absolute path
  final int? durationSecs;
  final DateTime createdAt;

  const GdRecording({
    this.id,
    this.sessionId,
    required this.remoteId,
    required this.filename,
    this.durationSecs,
    required this.createdAt,
  });

  String get baseName => p.basename(filename);

  bool get existsOnDisk {
    try {
      return File(filename).existsSync();
    } catch (_) {
      return false;
    }
  }

  int get sizeBytes {
    try {
      return existsOnDisk ? File(filename).lengthSync() : 0;
    } catch (_) {
      return 0;
    }
  }

  String get displaySize {
    final b = sizeBytes;
    if (b <= 0) return '--';
    if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(1)} KB';
    if (b < 1024 * 1024 * 1024) {
      return '${(b / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(b / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  String get displayDuration {
    if (durationSecs == null) return '--';
    final m = durationSecs! ~/ 60;
    final s = durationSecs! % 60;
    return m > 0 ? '${m}m ${s}s' : '${s}s';
  }

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'session_id': sessionId,
        'remote_id': remoteId,
        'filename': filename,
        'duration': durationSecs,
        'created_at': createdAt.toIso8601String(),
      };

  factory GdRecording.fromMap(Map<String, dynamic> map) => GdRecording(
        id: map['id'] as int?,
        sessionId: map['session_id'] as int?,
        remoteId: map['remote_id'] as String,
        filename: map['filename'] as String,
        durationSecs: map['duration'] as int?,
        createdAt: DateTime.parse(map['created_at'] as String),
      );

  /// Parse a recording from its absolute file path.
  /// Returns null if the basename does not match the RustDesk naming pattern.
  static GdRecording? fromFile(String absolutePath) {
    final base = p.basename(absolutePath);
    final m = _kFilenameRe.firstMatch(base);
    if (m == null) return null;
    final remoteId = m.group(2)!;
    final dtStr = m.group(3)!; // 17 chars: YYYYMMDDHHmmSSmmm
    DateTime dt;
    try {
      dt = DateTime(
        int.parse(dtStr.substring(0, 4)),   // year
        int.parse(dtStr.substring(4, 6)),   // month
        int.parse(dtStr.substring(6, 8)),   // day
        int.parse(dtStr.substring(8, 10)),  // hour
        int.parse(dtStr.substring(10, 12)), // minute
        int.parse(dtStr.substring(12, 14)), // second
        int.parse(dtStr.substring(14, 17)), // millisecond
      );
    } catch (_) {
      dt = DateTime.now();
    }
    return GdRecording(
      remoteId: remoteId,
      filename: absolutePath,
      createdAt: dt,
    );
  }
}
