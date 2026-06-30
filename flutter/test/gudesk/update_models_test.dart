import 'package:flutter_hbb/gudesk/update/update_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // ── semverCompare ─────────────────────────────────────────────────────────

  group('semverCompare', () {
    test('returns 0 for equal versions', () {
      expect(semverCompare('1.2.3', '1.2.3'), 0);
    });

    test('returns positive when a > b (patch)', () {
      expect(semverCompare('1.2.4', '1.2.3'), isPositive);
    });

    test('returns negative when a < b (patch)', () {
      expect(semverCompare('1.2.2', '1.2.3'), isNegative);
    });

    test('minor version takes precedence over patch', () {
      expect(semverCompare('1.3.0', '1.2.9'), isPositive);
    });

    test('major version takes precedence over minor', () {
      expect(semverCompare('2.0.0', '1.9.9'), isPositive);
    });

    test('strips leading v prefix', () {
      expect(semverCompare('v1.5.0', '1.4.8'), isPositive);
    });

    test('handles two-component versions', () {
      expect(semverCompare('1.5', '1.4.9'), isPositive);
    });

    test('handles equal two-component versions', () {
      expect(semverCompare('1.5', '1.5.0'), 0);
    });

    test('current version is not newer than itself', () {
      expect(semverCompare('1.4.8', '1.4.8'), 0);
    });
  });

  // ── GdUpdateManifest.fromJson ─────────────────────────────────────────────

  group('GdUpdateManifest.fromJson', () {
    const validJson = {
      'version': '2.0.0',
      'release_notes': 'Many improvements.',
      'published_at': '2026-07-01T12:00:00Z',
      'platforms': {
        'macos-aarch64': {
          'url': 'https://example.com/GuDesk-2.0.0.dmg',
          'sha256': 'abc123',
          'size': 30000000,
        },
        'windows-x86_64': {
          'url': 'https://example.com/GuDesk-Setup-2.0.0.exe',
          'sha256': 'def456',
          'size': 25000000,
        },
      },
    };

    test('parses version', () {
      final m = GdUpdateManifest.fromJson(validJson);
      expect(m.version, '2.0.0');
    });

    test('parses release notes', () {
      final m = GdUpdateManifest.fromJson(validJson);
      expect(m.releaseNotes, 'Many improvements.');
    });

    test('parses published_at', () {
      final m = GdUpdateManifest.fromJson(validJson);
      expect(m.publishedAt, '2026-07-01T12:00:00Z');
    });

    test('parses platform assets', () {
      final m = GdUpdateManifest.fromJson(validJson);
      expect(m.platforms.length, 2);
      expect(m.platforms['macos-aarch64']!.url, contains('2.0.0'));
      expect(m.platforms['macos-aarch64']!.sha256, 'abc123');
      expect(m.platforms['macos-aarch64']!.size, 30000000);
    });

    test('missing platforms key gives empty map', () {
      final m = GdUpdateManifest.fromJson({'version': '1.0.0'});
      expect(m.platforms, isEmpty);
    });

    test('missing version defaults to empty string', () {
      final m = GdUpdateManifest.fromJson({'platforms': <String, dynamic>{}});
      expect(m.version, '');
    });
  });

  // ── GdUpdateManifest.tryParse ─────────────────────────────────────────────

  group('GdUpdateManifest.tryParse', () {
    test('parses valid JSON string', () {
      const body = '''
      {
        "version": "1.5.0",
        "release_notes": "Faster.",
        "published_at": "2026-07-01T00:00:00Z",
        "platforms": {}
      }
      ''';
      final m = GdUpdateManifest.tryParse(body);
      expect(m, isNotNull);
      expect(m!.version, '1.5.0');
    });

    test('returns null for malformed JSON', () {
      expect(GdUpdateManifest.tryParse('{bad json}'), isNull);
    });

    test('returns null for empty string', () {
      expect(GdUpdateManifest.tryParse(''), isNull);
    });

    test('returns null for JSON array (wrong root type)', () {
      expect(GdUpdateManifest.tryParse('[1,2,3]'), isNull);
    });
  });

  // ── GdPlatformAsset.fromJson ──────────────────────────────────────────────

  group('GdPlatformAsset.fromJson', () {
    test('parses all fields', () {
      final a = GdPlatformAsset.fromJson({
        'url': 'https://example.com/file.dmg',
        'sha256': 'deadbeef',
        'size': 12345,
      });
      expect(a.url, 'https://example.com/file.dmg');
      expect(a.sha256, 'deadbeef');
      expect(a.size, 12345);
    });

    test('defaults missing fields', () {
      final a = GdPlatformAsset.fromJson(<String, dynamic>{});
      expect(a.url, '');
      expect(a.sha256, '');
      expect(a.size, 0);
    });
  });

  // ── GdDownloadProgress ────────────────────────────────────────────────────

  group('GdDownloadProgress', () {
    test('fraction is 0 when totalBytes is 0', () {
      const p = GdDownloadProgress(bytesReceived: 0, totalBytes: 0);
      expect(p.fraction, 0.0);
    });

    test('fraction computes correctly', () {
      const p = GdDownloadProgress(bytesReceived: 500, totalBytes: 1000);
      expect(p.fraction, closeTo(0.5, 0.001));
    });

    test('fraction clamps to 1.0 when overshot', () {
      const p = GdDownloadProgress(bytesReceived: 1100, totalBytes: 1000);
      expect(p.fraction, 1.0);
    });

    test('displayPercent at 50%', () {
      const p = GdDownloadProgress(bytesReceived: 500, totalBytes: 1000);
      expect(p.displayPercent, '50%');
    });

    test('displayPercent at 100%', () {
      const p = GdDownloadProgress(bytesReceived: 1000, totalBytes: 1000);
      expect(p.displayPercent, '100%');
    });
  });

  // ── gdFormatBytes ─────────────────────────────────────────────────────────

  group('gdFormatBytes', () {
    test('formats bytes', () {
      expect(gdFormatBytes(512), '512 B');
    });

    test('formats KB', () {
      expect(gdFormatBytes(2048), contains('KB'));
    });

    test('formats MB', () {
      expect(gdFormatBytes(5 * 1024 * 1024), contains('MB'));
    });

    test('formats GB', () {
      expect(gdFormatBytes(2 * 1024 * 1024 * 1024), contains('GB'));
    });
  });
}
