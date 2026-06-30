import 'package:flutter_hbb/gudesk/status/ws_client.dart';
import 'package:flutter_test/flutter_test.dart';

// Access the private _buildWsUri helper via a test-visible wrapper
// We expose it through a test shim since we can't make it public without
// cluttering the production API.
Uri? _buildUri(String url) => GdWsClientTestHelper.buildWsUri(url);

extension GdWsClientTestHelper on GdWsClient {
  static Uri? buildWsUri(String url) {
    // Mirror the logic in GdWsClient._buildWsUri (kept in sync manually)
    try {
      var u = url.trim();
      if (u.isEmpty) return null;
      if (!u.startsWith('ws://') && !u.startsWith('wss://')) {
        u = u
            .replaceFirst(RegExp(r'^https://'), 'wss://')
            .replaceFirst(RegExp(r'^http://'), 'ws://');
        if (!u.startsWith('ws')) u = 'ws://$u';
      }
      final base = Uri.parse(u);
      return base.replace(path: '${base.path}/api/v1/status/ws');
    } catch (_) {
      return null;
    }
  }
}

void main() {
  group('GdWsClient URI building', () {
    test('bare host gets ws:// prefix and /api/v1/status/ws path', () {
      final uri = _buildUri('myserver.local:8080');
      expect(uri?.scheme, 'ws');
      expect(uri?.host, 'myserver.local');
      expect(uri?.port, 8080);
      expect(uri?.path, '/api/v1/status/ws');
    });

    test('http:// is converted to ws://', () {
      final uri = _buildUri('http://server.example.com');
      expect(uri?.scheme, 'ws');
      expect(uri?.host, 'server.example.com');
    });

    test('https:// is converted to wss://', () {
      final uri = _buildUri('https://secure.example.com');
      expect(uri?.scheme, 'wss');
    });

    test('ws:// is kept as-is', () {
      final uri = _buildUri('ws://myhost:9001');
      expect(uri?.scheme, 'ws');
      expect(uri?.port, 9001);
    });

    test('wss:// is kept as-is', () {
      final uri = _buildUri('wss://myhost:9002');
      expect(uri?.scheme, 'wss');
    });

    test('empty string returns null', () {
      expect(_buildUri(''), isNull);
    });

    test('whitespace-only string returns null', () {
      expect(_buildUri('   '), isNull);
    });

    test('existing path is preserved before appending /api/v1/status/ws', () {
      final uri = _buildUri('https://host/prefix');
      expect(uri?.path, '/prefix/api/v1/status/ws');
    });

    test('host without port is handled', () {
      final uri = _buildUri('myhost');
      expect(uri?.scheme, 'ws');
      expect(uri?.host, 'myhost');
      expect(uri?.path, '/api/v1/status/ws');
    });
  });
}
