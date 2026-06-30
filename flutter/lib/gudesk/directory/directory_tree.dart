import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'device_card.dart';
import 'dialogs.dart';
import 'directory_controller.dart';
import 'models.dart';

class DirectoryTree extends StatelessWidget {
  const DirectoryTree({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = DirectoryController.to;
    return Obx(() {
      if (ctrl.isLoading.value) {
        return const Center(child: CircularProgressIndicator());
      }

      final roots = ctrl.rootDirectories();
      final unassigned = ctrl.unassignedDevices();

      return CustomScrollView(
        slivers: [
          // Root-level directories
          ...roots.map((dir) => SliverToBoxAdapter(
                child: _DirectoryNode(directory: dir, depth: 0),
              )),

          // Unassigned devices section
          if (unassigned.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: _UnassignedHeader(count: unassigned.length),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (ctx, i) => Padding(
                  padding: const EdgeInsets.only(left: 8, right: 4, bottom: 2),
                  child: GdDeviceCard(
                    device: unassigned[i],
                    onConnect: () => _connectDevice(ctx, unassigned[i]),
                  ),
                ),
                childCount: unassigned.length,
              ),
            ),
          ],

          // Empty state
          if (roots.isEmpty && unassigned.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.folder_open,
                        size: 48, color: Colors.grey.shade400),
                    const SizedBox(height: 12),
                    Text('No devices yet',
                        style: TextStyle(color: Colors.grey.shade500)),
                    const SizedBox(height: 8),
                    FilledButton.tonal(
                      onPressed: () => showAddDeviceDialog(context),
                      child: const Text('Add device'),
                    ),
                  ],
                ),
              ),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 16)),
        ],
      );
    });
  }

  void _connectDevice(BuildContext context, GdDevice device) {
    // Launch connection via RustDesk's existing mechanism
    // The remote ID is passed to the existing connect flow
    final id = device.remoteId;
    final ffi = Get.isRegistered(tag: 'main') ? Get.find(tag: 'main') : null;
    if (ffi != null) {
      // Use RustDesk's existing connect call if available
      try {
        (ffi as dynamic).connect(id: id);
      } catch (_) {}
    }
  }
}

// ── Directory node (recursive) ────────────────────────────────────────────

class _DirectoryNode extends StatelessWidget {
  final GdDirectory directory;
  final int depth;

  const _DirectoryNode({required this.directory, required this.depth});

  @override
  Widget build(BuildContext context) {
    final ctrl = DirectoryController.to;
    return Obx(() {
      final expanded = ctrl.isExpanded(directory.id!);
      final children = ctrl.childDirectories(directory.id!);
      final devices = ctrl.devicesIn(directory.id);

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Folder header row
          GestureDetector(
            onSecondaryTapUp: (d) => _showFolderMenu(context, d.globalPosition),
            child: InkWell(
              onTap: () => ctrl.toggleExpand(directory.id!),
              borderRadius: BorderRadius.circular(4),
              child: Container(
                height: 34,
                padding: EdgeInsets.only(left: 8.0 + depth * 16.0, right: 4),
                child: Row(
                  children: [
                    Icon(
                      expanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_right,
                      size: 16,
                      color: (children.isEmpty && devices.isEmpty)
                          ? Colors.transparent
                          : null,
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      expanded ? Icons.folder_open : Icons.folder,
                      size: 17,
                      color: const Color(0xFFFFA726),
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        directory.name,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    _FolderBadge(dirCount: children.length, deviceCount: devices.length),
                    _FolderActions(directory: directory),
                  ],
                ),
              ),
            ),
          ),

          // Children (animated)
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 160),
            crossFadeState: expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: EdgeInsets.only(left: depth == 0 ? 8.0 : 4.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Child directories (recursive)
                  ...children.map((child) => _DirectoryNode(
                        directory: child,
                        depth: depth + 1,
                      )),
                  // Devices in this directory
                  ...devices.map((device) => Padding(
                        padding: EdgeInsets.only(
                          left: 12.0 + depth * 16.0,
                          right: 4,
                          bottom: 2,
                        ),
                        child: GdDeviceCard(
                          device: device,
                          onConnect: () => _connectDevice(context, device),
                        ),
                      )),
                ],
              ),
            ),
          ),
        ],
      );
    });
  }

  void _showFolderMenu(BuildContext context, Offset position) async {
    final ctrl = DirectoryController.to;
    final result = await showMenu<_FolderAction>(
      context: context,
      position: RelativeRect.fromLTRB(
          position.dx, position.dy, position.dx, position.dy),
      items: [
        PopupMenuItem(
          value: _FolderAction.addDevice,
          child: ListTile(
            dense: true,
            leading: const Icon(Icons.add_circle_outline, size: 18),
            title: const Text('Add device here'),
          ),
        ),
        PopupMenuItem(
          value: _FolderAction.newSubfolder,
          child: ListTile(
            dense: true,
            leading: const Icon(Icons.create_new_folder_outlined, size: 18),
            title: const Text('New sub-folder'),
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: _FolderAction.rename,
          child: ListTile(
            dense: true,
            leading: const Icon(Icons.drive_file_rename_outline, size: 18),
            title: const Text('Rename'),
          ),
        ),
        PopupMenuItem(
          value: _FolderAction.expandAll,
          child: ListTile(
            dense: true,
            leading: const Icon(Icons.unfold_more, size: 18),
            title: const Text('Expand all'),
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: _FolderAction.delete,
          child: ListTile(
            dense: true,
            leading: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
            title: const Text('Delete folder', style: TextStyle(color: Colors.red)),
          ),
        ),
      ],
    );

    if (!context.mounted || result == null) return;
    switch (result) {
      case _FolderAction.addDevice:
        await showAddDeviceDialog(context, directoryId: directory.id);
      case _FolderAction.newSubfolder:
        await showCreateDirectoryDialog(context,
            parentId: directory.id, parentName: directory.name);
      case _FolderAction.rename:
        await showRenameDirectoryDialog(context, directory);
      case _FolderAction.expandAll:
        ctrl.expandAll();
      case _FolderAction.delete:
        await showDeleteDirectoryDialog(context, directory);
    }
  }

  void _connectDevice(BuildContext context, GdDevice device) {
    final ffi = Get.isRegistered(tag: 'main') ? Get.find(tag: 'main') : null;
    if (ffi != null) {
      try {
        (ffi as dynamic).connect(id: device.remoteId);
      } catch (_) {}
    }
  }
}

// ── Folder badge ──────────────────────────────────────────────────────────

class _FolderBadge extends StatelessWidget {
  final int dirCount;
  final int deviceCount;
  const _FolderBadge({required this.dirCount, required this.deviceCount});

  @override
  Widget build(BuildContext context) {
    if (dirCount == 0 && deviceCount == 0) return const SizedBox.shrink();
    final total = dirCount + deviceCount;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$total',
        style: TextStyle(
          fontSize: 10,
          color: Theme.of(context).colorScheme.onSecondaryContainer,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ── Folder action icons (hover-visible) ────────────────────────────────────

class _FolderActions extends StatefulWidget {
  final GdDirectory directory;
  const _FolderActions({required this.directory});

  @override
  State<_FolderActions> createState() => _FolderActionsState();
}

class _FolderActionsState extends State<_FolderActions> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: _hovered ? 1.0 : 0.0,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _iconBtn(
              icon: Icons.add,
              tooltip: 'Add device',
              onTap: () => showAddDeviceDialog(context, directoryId: widget.directory.id),
            ),
            _iconBtn(
              icon: Icons.create_new_folder_outlined,
              tooltip: 'New sub-folder',
              onTap: () => showCreateDirectoryDialog(context,
                  parentId: widget.directory.id, parentName: widget.directory.name),
            ),
          ],
        ),
      ),
    );
  }

  Widget _iconBtn({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) =>
      Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(4),
          child: Padding(
            padding: const EdgeInsets.all(3),
            child: Icon(icon, size: 14),
          ),
        ),
      );
}

// ── Unassigned header ─────────────────────────────────────────────────────

class _UnassignedHeader extends StatelessWidget {
  final int count;
  const _UnassignedHeader({required this.count});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 4, 4),
      child: Row(
        children: [
          const Icon(Icons.device_unknown_outlined, size: 15, color: Colors.grey),
          const SizedBox(width: 6),
          Text(
            'Unassigned',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade500,
              letterSpacing: 0.5,
            ),
          ),
          const Spacer(),
          Text(
            '$count',
            style: TextStyle(fontSize: 10, color: Colors.grey.shade400),
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }
}

enum _FolderAction { addDevice, newSubfolder, rename, expandAll, delete }
