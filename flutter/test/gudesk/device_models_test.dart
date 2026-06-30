import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_hbb/gudesk/directory/models.dart';

GdDevice _makeDevice({
  String remoteId = 'test-001',
  String? alias,
  List<String> tags = const [],
  String? notes,
  String hostname = '',
  String osDetail = '',
  String ipLast = '',
  GdDeviceStatus status = GdDeviceStatus.unknown,
}) {
  final now = DateTime(2026, 6, 30);
  return GdDevice(
    remoteId: remoteId,
    alias: alias,
    tags: tags,
    notes: notes,
    hostname: hostname,
    osDetail: osDetail,
    ipLast: ipLast,
    status: status,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  // ── GdDevice.displayName ──────────────────────────────────────────────────

  group('GdDevice.displayName', () {
    test('returns alias when set', () {
      final d = _makeDevice(alias: 'My Server');
      expect(d.displayName, 'My Server');
    });

    test('returns remoteId when alias is null', () {
      final d = _makeDevice();
      expect(d.displayName, 'test-001');
    });

    test('returns remoteId when alias is empty string', () {
      final d = _makeDevice(alias: '');
      expect(d.displayName, 'test-001');
    });
  });

  // ── GdDevice toMap / fromMap (new fields) ─────────────────────────────────

  group('GdDevice new fields serialization', () {
    test('hostname round-trips via toMap/fromMap', () {
      final d = _makeDevice(hostname: 'win-server-01');
      final m = d.toMap();
      expect(m['hostname'], 'win-server-01');
      final d2 = GdDevice.fromMap({
        ...m,
        'id': 1,
        'remote_id': d.remoteId,
        'status': 'UNKNOWN',
        'is_favorite': 0,
        'is_pinned': 0,
        'created_at': d.createdAt.toIso8601String(),
        'updated_at': d.updatedAt.toIso8601String(),
      });
      expect(d2.hostname, 'win-server-01');
    });

    test('osDetail round-trips via toMap/fromMap', () {
      final d = _makeDevice(osDetail: 'macOS 14.4 Sonoma');
      final m = d.toMap();
      expect(m['os_detail'], 'macOS 14.4 Sonoma');
      final d2 = GdDevice.fromMap({
        ...m,
        'id': 1,
        'remote_id': d.remoteId,
        'status': 'UNKNOWN',
        'is_favorite': 0,
        'is_pinned': 0,
        'created_at': d.createdAt.toIso8601String(),
        'updated_at': d.updatedAt.toIso8601String(),
      });
      expect(d2.osDetail, 'macOS 14.4 Sonoma');
    });

    test('ipLast round-trips via toMap/fromMap', () {
      final d = _makeDevice(ipLast: '192.168.1.42');
      final m = d.toMap();
      expect(m['ip_last'], '192.168.1.42');
      final d2 = GdDevice.fromMap({
        ...m,
        'id': 1,
        'remote_id': d.remoteId,
        'status': 'UNKNOWN',
        'is_favorite': 0,
        'is_pinned': 0,
        'created_at': d.createdAt.toIso8601String(),
        'updated_at': d.updatedAt.toIso8601String(),
      });
      expect(d2.ipLast, '192.168.1.42');
    });

    test('new fields default to empty string when absent from map', () {
      final d = GdDevice.fromMap({
        'remote_id': 'abc',
        'status': 'UNKNOWN',
        'is_favorite': 0,
        'is_pinned': 0,
        'tags': '[]',
        'created_at': '2026-01-01T00:00:00.000',
        'updated_at': '2026-01-01T00:00:00.000',
      });
      expect(d.hostname, '');
      expect(d.osDetail, '');
      expect(d.ipLast, '');
    });
  });

  // ── Tags serialization ────────────────────────────────────────────────────

  group('GdDevice tags serialization', () {
    test('tags round-trip as JSON in toMap/fromMap', () {
      final d = _makeDevice(tags: ['Production', 'Windows', 'Server']);
      final m = d.toMap();
      expect(m['tags'], isA<String>());
      final decoded = List<String>.from(jsonDecode(m['tags'] as String));
      expect(decoded, containsAll(['Production', 'Windows', 'Server']));
    });

    test('empty tags serialize as empty JSON array', () {
      final d = _makeDevice();
      final m = d.toMap();
      expect(m['tags'], '[]');
    });

    test('tags fromMap handles empty string gracefully', () {
      final d = GdDevice.fromMap({
        'remote_id': 'x',
        'status': 'UNKNOWN',
        'is_favorite': 0,
        'is_pinned': 0,
        'tags': '',
        'created_at': '2026-01-01T00:00:00.000',
        'updated_at': '2026-01-01T00:00:00.000',
      });
      expect(d.tags, isEmpty);
    });

    test('tags fromMap handles missing key gracefully', () {
      final d = GdDevice.fromMap({
        'remote_id': 'x',
        'status': 'UNKNOWN',
        'is_favorite': 0,
        'is_pinned': 0,
        'created_at': '2026-01-01T00:00:00.000',
        'updated_at': '2026-01-01T00:00:00.000',
      });
      expect(d.tags, isEmpty);
    });
  });

  // ── GdDevice.copyWith (new fields) ────────────────────────────────────────

  group('GdDevice.copyWith new fields', () {
    test('copyWith preserves hostname when not provided', () {
      final d = _makeDevice(hostname: 'original-host');
      final d2 = d.copyWith(alias: 'New alias');
      expect(d2.hostname, 'original-host');
    });

    test('copyWith updates hostname', () {
      final d = _makeDevice(hostname: 'old');
      final d2 = d.copyWith(hostname: 'new-host');
      expect(d2.hostname, 'new-host');
    });

    test('copyWith updates osDetail', () {
      final d = _makeDevice();
      final d2 = d.copyWith(osDetail: 'Windows 11 Pro');
      expect(d2.osDetail, 'Windows 11 Pro');
    });

    test('copyWith updates ipLast', () {
      final d = _makeDevice();
      final d2 = d.copyWith(ipLast: '10.0.0.1');
      expect(d2.ipLast, '10.0.0.1');
    });
  });

  // ── GdDeviceStatus ────────────────────────────────────────────────────────

  group('GdDeviceStatus', () {
    test('fromString parses ONLINE', () {
      expect(GdDeviceStatusExt.fromString('ONLINE'), GdDeviceStatus.online);
    });

    test('fromString is case-insensitive', () {
      expect(GdDeviceStatusExt.fromString('online'), GdDeviceStatus.online);
    });

    test('fromString falls back to unknown for unrecognised string', () {
      expect(GdDeviceStatusExt.fromString('SLEEPING'), GdDeviceStatus.unknown);
    });

    test('label returns uppercase string', () {
      expect(GdDeviceStatus.busy.label, 'BUSY');
    });
  });
}
