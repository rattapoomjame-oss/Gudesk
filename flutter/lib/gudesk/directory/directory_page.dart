import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../recording/recordings_page.dart';
import '../status/status_service.dart';
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
          // Status / connection indicator
          _StatusIndicator(),
        ],
      ),
    );
  }
}

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
