import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:get/get.dart';

// Reconnect schedule: 2s, 4s, 8s … capped at 60s
const _backoffBase = Duration(seconds: 2);
const _backoffCap = Duration(seconds: 60);
const _pingInterval = Duration(seconds: 30);

typedef StatusCallback = void Function(String remoteId, String status);
typedef BulkCallback = void Function(List<({String id, String status})> updates);

/// WebSocket client for the GuDesk API server realtime status channel.
///
/// Connects to `ws(s)://<host>/api/v1/status/ws` when a server URL is
/// configured. Falls back gracefully — callers check [isConnected].
///
/// Protocol (server → client):
///   {"type":"status","id":"<remote_id>","status":"ONLINE"|"OFFLINE"|...}
///   {"type":"bulk",  "devices":[{"id":"...","status":"..."},...]}
///   {"type":"pong"}
class GdWsClient {
  final String serverUrl;
  final StatusCallback onStatus;
  final BulkCallback onBulk;
  final void Function()? onConnect;
  final void Function()? onDisconnect;

  WebSocket? _ws;
  Timer? _reconnectTimer;
  Timer? _pingTimer;
  int _backoffMultiplier = 1;
  bool _disposed = false;

  final _connected = false.obs;
  bool get isConnected => _connected.value;

  GdWsClient({
    required this.serverUrl,
    required this.onStatus,
    required this.onBulk,
    this.onConnect,
    this.onDisconnect,
  });

  void connect() {
    if (_disposed) return;
    _doConnect();
  }

  void dispose() {
    _disposed = true;
    _reconnectTimer?.cancel();
    _pingTimer?.cancel();
    _ws?.close(WebSocketStatus.normalClosure);
    _ws = null;
  }

  Future<void> _doConnect() async {
    if (_disposed) return;
    final uri = _buildWsUri(serverUrl);
    if (uri == null) return;

    try {
      _ws = await WebSocket.connect(uri.toString()).timeout(const Duration(seconds: 8));
      _backoffMultiplier = 1;
      _connected.value = true;
      onConnect?.call();
      _startPing();

      _ws!.listen(
        _onMessage,
        onDone: _onClosed,
        onError: (_) => _onClosed(),
        cancelOnError: true,
      );
    } catch (_) {
      _scheduleReconnect();
    }
  }

  void _onMessage(dynamic raw) {
    if (raw is! String) return;
    try {
      final msg = jsonDecode(raw) as Map<String, dynamic>;
      switch (msg['type'] as String?) {
        case 'status':
          final id = msg['id'] as String?;
          final status = msg['status'] as String?;
          if (id != null && status != null) onStatus(id, status);
        case 'bulk':
          final list = (msg['devices'] as List?)
              ?.whereType<Map<String, dynamic>>()
              .map((d) => (
                    id: d['id'] as String? ?? '',
                    status: d['status'] as String? ?? 'UNKNOWN',
                  ))
              .where((d) => d.id.isNotEmpty)
              .toList();
          if (list != null && list.isNotEmpty) onBulk(list);
        case 'pong':
          break;
        default:
          break;
      }
    } catch (_) {}
  }

  void _onClosed() {
    _pingTimer?.cancel();
    _ws = null;
    if (_connected.value) {
      _connected.value = false;
      onDisconnect?.call();
    }
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_disposed) return;
    final delay = Duration(
      seconds: (_backoffBase.inSeconds * _backoffMultiplier)
          .clamp(0, _backoffCap.inSeconds),
    );
    _backoffMultiplier = (_backoffMultiplier * 2).clamp(1, 32);
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, _doConnect);
  }

  void _startPing() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(_pingInterval, (_) {
      try {
        _ws?.add('{"type":"ping"}');
      } catch (_) {}
    });
  }

  static Uri? _buildWsUri(String serverUrl) {
    try {
      var url = serverUrl.trim();
      if (url.isEmpty) return null;
      if (!url.startsWith('ws://') && !url.startsWith('wss://')) {
        // Accept http(s):// or bare host — convert to ws(s)
        url = url
            .replaceFirst(RegExp(r'^https://'), 'wss://')
            .replaceFirst(RegExp(r'^http://'), 'ws://');
        if (!url.startsWith('ws')) url = 'ws://$url';
      }
      final base = Uri.parse(url);
      return base.replace(path: '${base.path}/api/v1/status/ws');
    } catch (_) {
      return null;
    }
  }
}
