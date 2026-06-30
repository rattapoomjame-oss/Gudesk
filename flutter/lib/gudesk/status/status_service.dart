import 'dart:async';

import 'package:flutter_hbb/models/platform_model.dart';
import 'package:get/get.dart';

import '../directory/db.dart';
import '../directory/directory_controller.dart';
import '../directory/models.dart';
import 'ws_client.dart';

export 'formatting.dart';

const _kGdServerUrl = 'gudesk_api_server_url';
const _pollInterval = Duration(seconds: 10);
const _cbEvent = 'callback_query_onlines';
const _handlerName = 'gudesk_status';

/// Phase 3 — Online/Offline realtime status service.
///
/// Two complementary paths:
///   1. HBBS polling  — calls bind.queryOnlines every 10 s (always active)
///   2. WebSocket     — connects to GuDesk API server for sub-10s pushes;
///                      pauses polling while connected, resumes on disconnect
///
/// Both paths converge in [_applyStatus] which updates the in-memory
/// DirectoryController and persists last_seen to SQLite.
class GdStatusService extends GetxController {
  static GdStatusService get to => Get.find(tag: 'gudesk_status');

  final wsConnected = false.obs;
  final lastPollAt = Rxn<DateTime>();

  Timer? _pollTimer;
  GdWsClient? _wsClient;

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void onInit() {
    super.onInit();
    platformFFI.registerEventHandler(_cbEvent, _handlerName, _onHbbsCallback);
    _startPolling();
    _tryWebSocket();
  }

  @override
  void onClose() {
    platformFFI.unregisterEventHandler(_cbEvent, _handlerName);
    _pollTimer?.cancel();
    _wsClient?.dispose();
    super.onClose();
  }

  // ── Polling ───────────────────────────────────────────────────────────────

  void _startPolling() {
    _pollTimer?.cancel();
    // Immediate first poll, then every 10 s
    Future.microtask(_poll);
    _pollTimer = Timer.periodic(_pollInterval, (_) => _poll());
  }

  void _stopPolling() => _pollTimer?.cancel();

  void _poll() {
    if (!Get.isRegistered<DirectoryController>(tag: 'gudesk_directory')) return;
    final ids = DirectoryController.to.devices.map((d) => d.remoteId).toList();
    if (ids.isEmpty) return;
    try {
      bind.queryOnlines(ids: ids);
      lastPollAt.value = DateTime.now();
    } catch (_) {}
  }

  /// Triggered from outside (e.g. when user adds a device) to force an
  /// immediate poll without waiting for the next interval.
  void pollNow() => _poll();

  // ── HBBS callback ─────────────────────────────────────────────────────────

  Future<void> _onHbbsCallback(Map<String, dynamic> evt) async {
    final rawOnlines = evt['onlines'] as String? ?? '';
    final rawOfflines = evt['offlines'] as String? ?? '';
    final onlines = rawOnlines.split(',').where((s) => s.isNotEmpty).toList();
    final offlines = rawOfflines.split(',').where((s) => s.isNotEmpty).toList();
    for (final id in onlines) {
      await _applyStatus(id, GdDeviceStatus.online);
    }
    for (final id in offlines) {
      await _applyStatus(id, GdDeviceStatus.offline);
    }
  }

  // ── WebSocket ─────────────────────────────────────────────────────────────

  void _tryWebSocket() {
    final url = _readServerUrl();
    if (url.isEmpty) return;

    _wsClient = GdWsClient(
      serverUrl: url,
      onStatus: (id, status) =>
          _applyStatus(id, GdDeviceStatusExt.fromString(status)),
      onBulk: (updates) {
        for (final u in updates) {
          _applyStatus(u.id, GdDeviceStatusExt.fromString(u.status));
        }
      },
      onConnect: () {
        wsConnected.value = true;
        // Pause HBBS polling while WS delivers realtime updates
        _stopPolling();
      },
      onDisconnect: () {
        wsConnected.value = false;
        // Resume polling as fallback
        _startPolling();
      },
    );
    _wsClient!.connect();
  }

  /// Reconnect WebSocket with a new server URL (called from settings).
  void reconfigureWebSocket(String newUrl) {
    _wsClient?.dispose();
    _wsClient = null;
    wsConnected.value = false;
    _saveServerUrl(newUrl);
    if (newUrl.isNotEmpty) {
      _tryWebSocket();
    }
    if (!wsConnected.value) _startPolling();
  }

  // ── Core status update ────────────────────────────────────────────────────

  Future<void> _applyStatus(String remoteId, GdDeviceStatus status) async {
    if (!Get.isRegistered<DirectoryController>(tag: 'gudesk_directory')) return;
    final ctrl = DirectoryController.to;
    final idx = ctrl.devices.indexWhere((d) => d.remoteId == remoteId);
    if (idx == -1) return;

    final device = ctrl.devices[idx];
    if (device.status == status) return; // no change

    final now = DateTime.now().toIso8601String();
    // Record last_seen when going offline
    final lastSeen = (status == GdDeviceStatus.offline ||
            status == GdDeviceStatus.unknown)
        ? now
        : device.lastSeen;

    ctrl.devices[idx] = device.copyWith(status: status, lastSeen: lastSeen);

    // Persist asynchronously — don't block the UI
    GdDb.upsertDeviceStatus(remoteId, status.label).ignore();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  static String _readServerUrl() {
    try {
      return bind.getLocalFlutterOption(k: _kGdServerUrl);
    } catch (_) {
      return '';
    }
  }

  static void _saveServerUrl(String url) {
    try {
      bind.setLocalFlutterOption(k: _kGdServerUrl, v: url);
    } catch (_) {}
  }

  String get configuredServerUrl => _readServerUrl();
}
