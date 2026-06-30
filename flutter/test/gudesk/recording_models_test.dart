import 'package:flutter_hbb/gudesk/recording/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // ── GdRecording.fromFile ─────────────────────────────────────────────────

  group('GdRecording.fromFile', () {
    test('parses a valid outgoing mp4 filename', () {
      const path =
          '/recordings/outgoing_123456789_20260630143022050_display0_h264.mp4';
      final r = GdRecording.fromFile(path);
      expect(r, isNotNull);
      expect(r!.remoteId, '123456789');
      expect(r.createdAt.year, 2026);
      expect(r.createdAt.month, 6);
      expect(r.createdAt.day, 30);
      expect(r.createdAt.hour, 14);
      expect(r.createdAt.minute, 30);
      expect(r.createdAt.second, 22);
      expect(r.createdAt.millisecond, 50);
      expect(r.filename, path);
    });

    test('parses a valid incoming webm filename', () {
      const path =
          '/recordings/incoming_ABC-123_20260101090000000_camera0_vp9.webm';
      final r = GdRecording.fromFile(path);
      expect(r, isNotNull);
      expect(r!.remoteId, 'ABC-123');
      expect(r.createdAt.year, 2026);
      expect(r.createdAt.month, 1);
      expect(r.createdAt.day, 1);
      expect(r.createdAt.hour, 9);
    });

    test('parses remote_id with dots and hyphens', () {
      const path =
          '/tmp/outgoing_192.168.1.42_20260515120000000_display1_h265.mp4';
      final r = GdRecording.fromFile(path);
      expect(r, isNotNull);
      expect(r!.remoteId, '192.168.1.42');
    });

    test('returns null for a non-matching filename', () {
      expect(GdRecording.fromFile('/recordings/my_video.mp4'), isNull);
      expect(GdRecording.fromFile('/recordings/some_random_file.txt'), isNull);
    });

    test('returns null for empty string', () {
      expect(GdRecording.fromFile(''), isNull);
    });

    test('session_id and duration are null when fromFile is used', () {
      final r = GdRecording.fromFile(
          '/outgoing_100_20260101120000000_display0_h264.mp4');
      expect(r!.sessionId, isNull);
      expect(r.durationSecs, isNull);
    });
  });

  // ── GdRecording.displaySize ───────────────────────────────────────────────

  group('GdRecording.displaySize', () {
    // We can't easily test files on disk in unit tests, so test the pure logic
    // by subclassing or just testing the branches via known sizes.
    // Instead we test via the returned GdRecording from a known constructed instance.

    GdRecording _make({int? dur}) => GdRecording(
          remoteId: 'test',
          filename: '/nonexistent_path/file.mp4',
          createdAt: DateTime(2026),
          durationSecs: dur,
        );

    test('displaySize returns "--" for nonexistent file (sizeBytes == 0)', () {
      expect(_make().displaySize, '--');
    });

    test('displayDuration returns "--" when durationSecs is null', () {
      expect(_make().displayDuration, '--');
    });

    test('displayDuration formats seconds only', () {
      expect(_make(dur: 45).displayDuration, '45s');
    });

    test('displayDuration formats minutes and seconds', () {
      expect(_make(dur: 125).displayDuration, '2m 5s');
    });

    test('displayDuration formats 0 seconds', () {
      expect(_make(dur: 0).displayDuration, '0s');
    });

    test('displayDuration formats exactly 60 seconds as 1m 0s', () {
      expect(_make(dur: 60).displayDuration, '1m 0s');
    });
  });

  // ── GdRecording toMap / fromMap roundtrip ─────────────────────────────────

  group('GdRecording serialization', () {
    test('roundtrip preserves all fields', () {
      final original = GdRecording(
        id: 7,
        sessionId: 3,
        remoteId: '999',
        filename: '/recordings/file.mp4',
        durationSecs: 120,
        createdAt: DateTime(2026, 6, 15, 10, 30),
      );
      final map = original.toMap();
      final restored = GdRecording.fromMap(map);
      expect(restored.id, 7);
      expect(restored.sessionId, 3);
      expect(restored.remoteId, '999');
      expect(restored.filename, '/recordings/file.mp4');
      expect(restored.durationSecs, 120);
      expect(restored.createdAt.year, 2026);
      expect(restored.createdAt.month, 6);
      expect(restored.createdAt.day, 15);
    });

    test('null session_id roundtrips as null', () {
      final r = GdRecording(
        remoteId: 'x',
        filename: '/f.mp4',
        createdAt: DateTime(2026),
      );
      final map = r.toMap();
      final r2 = GdRecording.fromMap(map);
      expect(r2.sessionId, isNull);
      expect(r2.durationSecs, isNull);
    });
  });

  // ── GdSession serialization ───────────────────────────────────────────────

  group('GdSession serialization', () {
    test('roundtrip preserves all fields', () {
      final s = GdSession(
        id: 1,
        remoteId: '555',
        startTime: DateTime(2026, 3, 1, 8, 0),
        endTime: DateTime(2026, 3, 1, 9, 0),
        mode: 'view_only',
        recorded: true,
      );
      final map = s.toMap();
      final s2 = GdSession.fromMap(map);
      expect(s2.id, 1);
      expect(s2.remoteId, '555');
      expect(s2.mode, 'view_only');
      expect(s2.recorded, isTrue);
      expect(s2.endTime, isNotNull);
    });

    test('null endTime roundtrips as null', () {
      final s = GdSession(
        remoteId: 'r',
        startTime: DateTime(2026),
      );
      final s2 = GdSession.fromMap(s.toMap());
      expect(s2.endTime, isNull);
      expect(s2.recorded, isFalse);
    });

    test('duration computed from start and end times', () {
      final s = GdSession(
        remoteId: 'r',
        startTime: DateTime(2026, 1, 1, 12, 0),
        endTime: DateTime(2026, 1, 1, 12, 30),
      );
      expect(s.duration?.inMinutes, 30);
    });

    test('duration is null when endTime is null', () {
      final s = GdSession(remoteId: 'r', startTime: DateTime(2026));
      expect(s.duration, isNull);
    });
  });
}
