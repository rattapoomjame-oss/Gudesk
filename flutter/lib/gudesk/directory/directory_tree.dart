import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hbb/common.dart';
import 'package:get/get.dart';

import '../cloud/cloud_controller.dart';
import 'connect_dialog.dart';
import 'device_card.dart';
import 'dialogs.dart';
import 'directory_controller.dart';
import 'models.dart';

/// Connects to [device].
///
/// When GuDesk Cloud is logged in, the org has "Elevated Access Mode" on
/// (an admin-only toggle in the web dashboard), the current user is
/// it_manager/super_admin, and this device is one already enrolled in the
/// org's directory (has a `cloudId`) with a stored password: connects
/// straight away with that password, no dialog. This never changes what
/// happens on the *target* device's own screen — that's controlled entirely
/// by that device's own local approve-mode setting.
///
/// Otherwise, shows GuDesk's own connect dialog (password entry + optional
/// "remember this password" — see connect_dialog.dart) rather than jumping
/// straight to RustDesk's generic connect flow.
void _connectToDevice(BuildContext context, GdDevice device) {
  if (Get.isRegistered<GdCloudController>(tag: GdCloudController.tag)) {
    final cloud = Get.find<GdCloudController>(tag: GdCloudController.tag);
    final user = cloud.currentUser.value;
    if (cloud.isLoggedIn.value &&
        cloud.elevatedAccessEnabled.value &&
        (user?.isManager ?? false) &&
        device.cloudId != null &&
        device.password.isNotEmpty) {
      connect(context, device.remoteId,
          password: device.password, isSharedPassword: true);
      cloud.logConnectionUse(device.cloudId!);
      return;
    }
  }

  showConnectDialog(context, device);
}

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
                    Icon(CupertinoIcons.folder_open,
                        size: 48, color: Colors.grey.shade400),
                    const SizedBox(height: 16),
                    Text('No devices yet',
                        style: TextStyle(
                            fontSize: 15, color: Colors.grey.shade500)),
                    const SizedBox(height: 12),
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

  void _connectDevice(BuildContext context, GdDevice device) =>
      _connectToDevice(context, device);
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
              borderRadius: BorderRadius.circular(MyTheme.radiusSmall),
              child: Container(
                height: 38,
                padding: EdgeInsets.only(left: 8.0 + depth * 16.0, right: 6),
                child: Row(
                  children: [
                    Icon(
                      expanded ? CupertinoIcons.chevron_down : CupertinoIcons.chevron_right,
                      size: 14,
                      color: (children.isEmpty && devices.isEmpty)
                          ? Colors.transparent
                          : Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.6),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      expanded ? CupertinoIcons.folder_open : CupertinoIcons.folder,
                      size: 17,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        directory.name,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
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
            leading: const Icon(CupertinoIcons.add_circled, size: 18),
            title: const Text('Add device here', style: TextStyle(fontSize: 15)),
          ),
        ),
        PopupMenuItem(
          value: _FolderAction.newSubfolder,
          child: ListTile(
            dense: true,
            leading: const Icon(CupertinoIcons.folder_badge_plus, size: 18),
            title: const Text('New sub-folder', style: TextStyle(fontSize: 15)),
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: _FolderAction.rename,
          child: ListTile(
            dense: true,
            leading: const Icon(CupertinoIcons.pencil, size: 18),
            title: const Text('Rename', style: TextStyle(fontSize: 15)),
          ),
        ),
        PopupMenuItem(
          value: _FolderAction.expandAll,
          child: ListTile(
            dense: true,
            leading: const Icon(Icons.unfold_more, size: 18),
            title: const Text('Expand all', style: TextStyle(fontSize: 15)),
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: _FolderAction.delete,
          child: ListTile(
            dense: true,
            leading: Icon(CupertinoIcons.trash,
                size: 18, color: MyTheme.color(context).statusError),
            title: Text('Delete folder',
                style: TextStyle(
                    fontSize: 15, color: MyTheme.color(context).statusError)),
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

  void _connectDevice(BuildContext context, GdDevice device) =>
      _connectToDevice(context, device);
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
          fontSize: 12,
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
              icon: CupertinoIcons.add,
              tooltip: 'Add device',
              onTap: () => showAddDeviceDialog(context, directoryId: widget.directory.id),
            ),
            _iconBtn(
              icon: CupertinoIcons.folder_badge_plus,
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
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade500,
              letterSpacing: 0.5,
            ),
          ),
          const Spacer(),
          Text(
            '$count',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }
}

enum _FolderAction { addDevice, newSubfolder, rename, expandAll, delete }
