import 'package:flutter_hbb/gudesk/directory/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GdDeviceStatus', () {
    test('fromString round-trips all values', () {
      for (final status in GdDeviceStatus.values) {
        expect(GdDeviceStatusExt.fromString(status.label), status);
      }
    });

    test('fromString is case-insensitive', () {
      expect(GdDeviceStatusExt.fromString('online'), GdDeviceStatus.online);
      expect(GdDeviceStatusExt.fromString('OFFLINE'), GdDeviceStatus.offline);
    });

    test('unknown string returns unknown status', () {
      expect(GdDeviceStatusExt.fromString(''), GdDeviceStatus.unknown);
      expect(GdDeviceStatusExt.fromString('bogus'), GdDeviceStatus.unknown);
    });
  });

  group('GdDirectory', () {
    final now = DateTime(2026, 1, 1);

    test('toMap / fromMap round-trip', () {
      final dir = GdDirectory(
        id: 1,
        name: 'Servers',
        parentId: null,
        createdAt: now,
        updatedAt: now,
      );
      final map = dir.toMap();
      final restored = GdDirectory.fromMap(map);

      expect(restored.id, dir.id);
      expect(restored.name, dir.name);
      expect(restored.parentId, dir.parentId);
    });

    test('copyWith preserves unmodified fields', () {
      final dir = GdDirectory(
        id: 1,
        name: 'Original',
        parentId: 2,
        createdAt: now,
        updatedAt: now,
      );
      final copy = dir.copyWith(name: 'Renamed');
      expect(copy.id, 1);
      expect(copy.name, 'Renamed');
      expect(copy.parentId, 2);
    });

    test('toMap excludes id when null', () {
      final dir = GdDirectory(
        name: 'NoId',
        parentId: null,
        createdAt: now,
        updatedAt: now,
      );
      expect(dir.toMap().containsKey('id'), isFalse);
    });
  });

  group('GdDevice', () {
    final now = DateTime(2026, 1, 1);

    test('displayName returns alias when set', () {
      final d = GdDevice(
        remoteId: '123',
        alias: 'CEO MacBook',
        createdAt: now,
        updatedAt: now,
      );
      expect(d.displayName, 'CEO MacBook');
    });

    test('displayName falls back to remoteId', () {
      final d = GdDevice(remoteId: '456', createdAt: now, updatedAt: now);
      expect(d.displayName, '456');
    });

    test('toMap / fromMap round-trips tags as JSON', () {
      final d = GdDevice(
        remoteId: '789',
        tags: ['Accounting', 'CEO'],
        createdAt: now,
        updatedAt: now,
      );
      final restored = GdDevice.fromMap(d.toMap());
      expect(restored.tags, ['Accounting', 'CEO']);
    });

    test('fromMap handles empty tags field gracefully', () {
      final d = GdDevice(remoteId: 'x', createdAt: now, updatedAt: now);
      final map = d.toMap();
      map['tags'] = '[]';
      expect(GdDevice.fromMap(map).tags, isEmpty);
    });

    test('fromMap handles malformed tags without throwing', () {
      final d = GdDevice(remoteId: 'x', createdAt: now, updatedAt: now);
      final map = d.toMap();
      map['tags'] = 'not-json';
      expect(() => GdDevice.fromMap(map), returnsNormally);
      expect(GdDevice.fromMap(map).tags, isEmpty);
    });

    test('isFavorite / isPinned default to false', () {
      final d = GdDevice(remoteId: 'x', createdAt: now, updatedAt: now);
      expect(d.isFavorite, isFalse);
      expect(d.isPinned, isFalse);
    });

    test('isFavorite encoded as 1/0 in map', () {
      final d = GdDevice(
        remoteId: 'x',
        isFavorite: true,
        isPinned: true,
        createdAt: now,
        updatedAt: now,
      );
      final map = d.toMap();
      expect(map['is_favorite'], 1);
      expect(map['is_pinned'], 1);
    });

    test('copyWith with nullable directoryId sentinel', () {
      final d = GdDevice(
        remoteId: 'x',
        directoryId: 5,
        createdAt: now,
        updatedAt: now,
      );
      // Explicitly clear directoryId
      final cleared = d.copyWith(directoryId: null);
      expect(cleared.directoryId, isNull);
      // Not passing directoryId preserves the original
      final kept = d.copyWith(alias: 'test');
      expect(kept.directoryId, 5);
    });

    test('status round-trips through map', () {
      for (final status in GdDeviceStatus.values) {
        final d = GdDevice(
          remoteId: 'x',
          status: status,
          createdAt: now,
          updatedAt: now,
        );
        expect(GdDevice.fromMap(d.toMap()).status, status);
      }
    });
  });
}
