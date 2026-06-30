import 'package:flutter_hbb/gudesk/status/formatting.dart';
import 'package:flutter_hbb/gudesk/directory/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('formatLastSeen', () {
    test('returns "Now" for online status regardless of timestamp', () {
      expect(
        formatLastSeen('2020-01-01T00:00:00.000Z', GdDeviceStatus.online),
        'Now',
      );
    });

    test('returns "Now" for connecting status', () {
      expect(
        formatLastSeen(null, GdDeviceStatus.connecting),
        'Now',
      );
    });

    test('returns "Unknown" for null timestamp when offline', () {
      expect(
        formatLastSeen(null, GdDeviceStatus.offline),
        'Unknown',
      );
    });

    test('returns "Unknown" for empty timestamp when offline', () {
      expect(
        formatLastSeen('', GdDeviceStatus.offline),
        'Unknown',
      );
    });

    test('returns "Just now" for timestamps within 60 seconds', () {
      final recent = DateTime.now().subtract(const Duration(seconds: 30));
      final result = formatLastSeen(recent.toIso8601String(), GdDeviceStatus.offline);
      expect(result, 'Just now');
    });

    test('returns minutes ago for timestamps 1-59 minutes ago', () {
      final dt = DateTime.now().subtract(const Duration(minutes: 25));
      final result = formatLastSeen(dt.toIso8601String(), GdDeviceStatus.offline);
      expect(result, '25 min ago');
    });

    test('returns hours ago for timestamps 1-23 hours ago', () {
      final dt = DateTime.now().subtract(const Duration(hours: 3));
      final result = formatLastSeen(dt.toIso8601String(), GdDeviceStatus.offline);
      expect(result, '3h ago');
    });

    test('returns "Yesterday" for exactly 1 day ago', () {
      final dt = DateTime.now().subtract(const Duration(hours: 25));
      final result = formatLastSeen(dt.toIso8601String(), GdDeviceStatus.offline);
      expect(result, 'Yesterday');
    });

    test('returns days ago for 2-6 days ago', () {
      final dt = DateTime.now().subtract(const Duration(days: 4));
      final result = formatLastSeen(dt.toIso8601String(), GdDeviceStatus.offline);
      expect(result, '4 days ago');
    });

    test('returns date string for >= 7 days ago', () {
      final dt = DateTime(2026, 1, 15);
      final result = formatLastSeen(dt.toIso8601String(), GdDeviceStatus.offline);
      // Should be a date like "2026-01-15"
      expect(result, contains('2026'));
      expect(result, contains('01'));
      expect(result, contains('15'));
    });

    test('returns "Unknown" for malformed timestamp', () {
      final result = formatLastSeen('not-a-date', GdDeviceStatus.offline);
      expect(result, 'Unknown');
    });

    test('works for unknown status', () {
      final dt = DateTime.now().subtract(const Duration(minutes: 5));
      final result = formatLastSeen(dt.toIso8601String(), GdDeviceStatus.unknown);
      expect(result, '5 min ago');
    });
  });

  group('statusLabel', () {
    test('returns correct label for each status', () {
      expect(statusLabel(GdDeviceStatus.online), 'Online');
      expect(statusLabel(GdDeviceStatus.offline), 'Offline');
      expect(statusLabel(GdDeviceStatus.connecting), 'Connecting…');
      expect(statusLabel(GdDeviceStatus.busy), 'Busy');
      expect(statusLabel(GdDeviceStatus.unknown), 'Unknown');
    });
  });
}
