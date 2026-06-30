import 'dart:convert';

import 'package:flutter_hbb/common.dart';
import 'package:get/get.dart';

import '../directory/db.dart';
import '../directory/directory_controller.dart';

const _kEventName = 'load_recent_peers';
const _kHandlerTag = 'gudesk_peer_info_sync';

/// Listens to the upstream `load_recent_peers` event (fired after every
/// connection and on startup) and syncs hostname + platform into the
/// GuDesk devices table for any peer that is already registered.
class GdPeerInfoListener {
  static final instance = GdPeerInfoListener._();
  GdPeerInfoListener._();

  bool _started = false;

  void start() {
    if (_started) return;
    _started = true;
    platformFFI.registerEventHandler(
      _kEventName,
      _kHandlerTag,
      _onEvent,
    );
  }

  Future<void> _onEvent(Map<String, dynamic> evt) async {
    final peersRaw = evt['peers'];
    if (peersRaw == null || peersRaw is! String || peersRaw.isEmpty) return;

    List<dynamic> peers;
    try {
      peers = jsonDecode(peersRaw) as List<dynamic>;
    } catch (_) {
      return;
    }

    // Only update devices that exist in the GuDesk directory
    if (!Get.isRegistered<DirectoryController>(tag: 'gudesk_directory')) return;
    final ctrl = DirectoryController.to;
    final knownIds = ctrl.devices.map((d) => d.remoteId).toSet();
    if (knownIds.isEmpty) return;

    bool anyUpdated = false;
    for (final raw in peers) {
      final peer = raw as Map<String, dynamic>?;
      if (peer == null) continue;
      final id = peer['id'] as String?;
      if (id == null || !knownIds.contains(id)) continue;

      await GdDb.patchDeviceInfo(
        id,
        hostname: peer['hostname'] as String?,
        platform: peer['platform'] as String?,
      );
      anyUpdated = true;
    }

    if (anyUpdated) await ctrl.load();
  }
}
