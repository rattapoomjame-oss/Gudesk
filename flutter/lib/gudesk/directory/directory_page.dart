import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../cloud/cloud_controller.dart';
import '../cloud/login_page.dart';
import '../recording/recordings_page.dart';
import '../status/status_service.dart';
import '../device/peer_info_listener.dart';
import '../update/update_controller.dart';
import '../update/update_dialog.dart';
import 'dialogs.dart';
import 'directory_controller.dart';
import 'directory_tree.dart';

class DirectoryPage extends StatefulWidget {
  final EdgeInsets? menuPadding;
  const DirectoryPage({super.key, this.menuPadding});

  @override
  State<DirectoryPage> createState() => _DirectoryPageState();
}

class _DirectoryPageState extends State<DirectoryPage> {
  late final DirectoryController _ctrl;

  @override
  void initState() {
    super.initState();
    if (!Get.isRegistered<DirectoryController>(tag: 'gudesk_directory')) {
      Get.put(DirectoryController(), tag: 'gudesk_directory', permanent: true);
    }
    if (!Get.isRegistered<GdStatusService>(tag: 'gudesk_status')) {
      Get.put(GdStatusService(), tag: 'gudesk_status', permanent: true);
    }
    if (!Get.isRegistered<GdUpdateController>(tag: 'gudesk_update')) {
      Get.put(GdUpdateController(), tag: 'gudesk_update', permanent: true);
    }
    if (!Get.isRegistered<GdCloudController>(tag: GdCloudController.tag)) {
      Get.put(GdCloudController(), tag: GdCloudController.tag, permanent: true);
    }
    GdPeerInfoListener.instance.start();
    _ctrl = DirectoryController.to;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _Toolbar(ctrl: _ctrl),
        const Divider(height: 1),
        const Expanded(child: DirectoryTree()),
      ],
    );
  }
}

// ── Toolbar ───────────────────────────────────────────────────────────────

class _Toolbar extends StatelessWidget {
  final DirectoryController ctrl;
  const _Toolbar({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: [
          // Search
          Expanded(
            child: Obx(() => TextField(
                  onChanged: (v) => ctrl.searchQuery.value = v,
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: 'Search devices, tags…',
                    hintStyle: const TextStyle(fontSize: 12),
                    prefixIcon: const Icon(Icons.search, size: 16),
                    suffixIcon: ctrl.searchQuery.value.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 14),
                            onPressed: () => ctrl.searchQuery.value = '',
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        vertical: 6, horizontal: 8),
                  ),
                  style: const TextStyle(fontSize: 12),
                )),
          ),
          const SizedBox(width: 6),
          // New folder
          Tooltip(
            message: 'New root folder',
            child: IconButton(
              icon: const Icon(Icons.create_new_folder_outlined, size: 20),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              onPressed: () => showCreateDirectoryDialog(context),
            ),
          ),
          // Add device
          Tooltip(
            message: 'Add device',
            child: IconButton(
              icon: const Icon(Icons.add_circle_outline, size: 20),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              onPressed: () => showAddDeviceDialog(context),
            ),
          ),
          // Expand / collapse all
          Obx(() {
            final allExpanded = ctrl.directories.isNotEmpty &&
                ctrl.directories.every((d) => ctrl.isExpanded(d.id!));
            return Tooltip(
              message: allExpanded ? 'Collapse all' : 'Expand all',
              child: IconButton(
                icon: Icon(
                  allExpanded ? Icons.unfold_less : Icons.unfold_more,
                  size: 20,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                onPressed: allExpanded ? ctrl.collapseAll : ctrl.expandAll,
              ),
            );
          }),
          // Tag filter
          _TagFilterButton(ctrl: ctrl),
          // Recordings browser
          Tooltip(
            message: 'Session recordings',
            child: IconButton(
              icon: const Icon(Icons.video_library_outlined, size: 20),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const RecordingsPage()),
              ),
            ),
          ),
          // Update badge (hidden when idle)
          const GdUpdateBadge(),
          // Cloud sync
          const _CloudSyncButton(),
          // Status / connection indicator
          _StatusIndicator(),
        ],
      ),
    );
  }
}

// ── Tag filter button ─────────────────────────────────────────────────────

/// Toolbar button that opens a tag picker; active when a tag filter is set.
class _TagFilterButton extends StatelessWidget {
  final DirectoryController ctrl;
  const _TagFilterButton({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final active = ctrl.tagFilter.value.isNotEmpty;
      return Tooltip(
        message: active
            ? 'Tag filter: ${ctrl.tagFilter.value} (tap to clear)'
            : 'Filter by tag',
        child: IconButton(
          icon: Badge(
            isLabelVisible: active,
            backgroundColor: Theme.of(context).colorScheme.primary,
            child: Icon(
              Icons.label_outline,
              size: 20,
              color: active
                  ? Theme.of(context).colorScheme.primary
                  : null,
            ),
          ),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          onPressed: active
              ? () => ctrl.tagFilter.value = ''
              : () => _showTagPicker(context),
        ),
      );
    });
  }

  Future<void> _showTagPicker(BuildContext context) async {
    final tags = ctrl.allTags();
    if (tags.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No tags yet — add tags to devices via Info & Notes'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    final selected = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Filter by tag'),
        children: [
          for (final tag in tags)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, tag),
              child: Row(
                children: [
                  const Icon(Icons.label, size: 16),
                  const SizedBox(width: 8),
                  Text(tag),
                ],
              ),
            ),
        ],
      ),
    );
    if (selected != null) ctrl.tagFilter.value = selected;
  }
}

// ── Cloud sync button ─────────────────────────────────────────────────────

/// Toolbar button for GuDesk Cloud: shows login or sync state.
class _CloudSyncButton extends StatelessWidget {
  const _CloudSyncButton();

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<GdCloudController>(tag: GdCloudController.tag)) {
      return const SizedBox.shrink();
    }
    final ctrl = Get.find<GdCloudController>(tag: GdCloudController.tag);
    return Obx(() {
      final loggedIn  = ctrl.isLoggedIn.value;
      final syncing   = ctrl.isSyncing.value;
      final hasError  = ctrl.syncError.value != null;
      final lastSync  = ctrl.lastSyncedAt.value;

      String tooltip;
      if (!loggedIn) {
        tooltip = 'Sign in to GuDesk Cloud';
      } else if (syncing) {
        tooltip = 'Syncing directory…';
      } else if (hasError) {
        tooltip = 'Sync error — tap to retry';
      } else if (lastSync != null) {
        tooltip = 'Cloud: ${ctrl.currentOrg.value?.name ?? ''}'
            ' · Synced ${_ago(lastSync)} · Tap to refresh';
      } else {
        tooltip = 'Cloud: ${ctrl.currentOrg.value?.name ?? ''} · Tap to sync';
      }

      return Tooltip(
        message: tooltip,
        child: loggedIn
            ? _syncedButton(context, ctrl, syncing, hasError)
            : IconButton(
                icon: const Icon(Icons.cloud_off_outlined, size: 20),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                onPressed: () => _openLogin(context),
              ),
      );
    });
  }

  Widget _syncedButton(
    BuildContext context,
    GdCloudController ctrl,
    bool syncing,
    bool hasError,
  ) {
    return PopupMenuButton<_CloudAction>(
      icon: syncing
          ? const SizedBox(
              width: 20, height: 20,
              child: CircularProgressIndicator(strokeWidth: 2))
          : Icon(
              hasError ? Icons.cloud_off : Icons.cloud_done_outlined,
              size: 20,
              color: hasError ? Colors.orange : Colors.green,
            ),
      padding: EdgeInsets.zero,
      iconSize: 20,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      onSelected: (action) {
        switch (action) {
          case _CloudAction.sync:
            ctrl.syncDirectory();
          case _CloudAction.logout:
            _confirmLogout(context, ctrl);
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem(
          value: _CloudAction.sync,
          child: Row(children: const [
            Icon(Icons.sync, size: 18),
            SizedBox(width: 8),
            Text('Refresh directory'),
          ]),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: _CloudAction.logout,
          child: Row(children: [
            Icon(Icons.logout, size: 18,
                color: Theme.of(context).colorScheme.error),
            const SizedBox(width: 8),
            Text('Sign out',
                style: TextStyle(
                    color: Theme.of(context).colorScheme.error)),
          ]),
        ),
      ],
    );
  }

  void _openLogin(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const GdLoginPage()),
    );
  }

  void _confirmLogout(BuildContext context, GdCloudController ctrl) {
    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign out of GuDesk Cloud?'),
        content: const Text(
            'Your local directory will remain intact. Cloud contacts will no longer sync.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () { Navigator.pop(ctx); ctrl.logout(); },
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
  }

  String _ago(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60)  return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60)  return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ago';
  }
}

enum _CloudAction { sync, logout }

/// Small icon showing WebSocket / poll status, with settings on tap.
class _StatusIndicator extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<GdStatusService>(tag: 'gudesk_status')) {
      return const SizedBox.shrink();
    }
    final svc = GdStatusService.to;
    return Obx(() {
      final wsOk = svc.wsConnected.value;
      final lastPoll = svc.lastPollAt.value;
      final tooltip = wsOk
          ? 'Realtime status: connected'
          : lastPoll != null
              ? 'Polling status (last: ${_ago(lastPoll)})'
              : 'Status: waiting for first poll…';

      return Tooltip(
        message: tooltip,
        child: IconButton(
          icon: Icon(
            wsOk ? Icons.wifi : Icons.sync,
            size: 18,
            color: wsOk ? Colors.green : Colors.grey,
          ),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          onPressed: () => _showStatusSettings(context, svc),
        ),
      );
    });
  }

  String _ago(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    return '${diff.inMinutes}m ago';
  }

  void _showStatusSettings(BuildContext context, GdStatusService svc) {
    final urlCtrl = TextEditingController(text: svc.configuredServerUrl);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Status server'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'GuDesk API server URL for realtime status.\n'
              'Leave empty to use HBBS polling only.',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: urlCtrl,
              decoration: const InputDecoration(
                labelText: 'Server URL',
                hintText: 'https://your-gudesk-server',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              svc.reconfigureWebSocket(urlCtrl.text.trim());
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
