import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hbb/common.dart';

import '../chat/chat_history_page.dart';
import '../device/device_detail_page.dart';
import '../status/formatting.dart';
import 'dialogs.dart';
import 'directory_controller.dart';
import 'models.dart';

class GdDeviceCard extends StatelessWidget {
  final GdDevice device;
  final VoidCallback? onConnect;

  const GdDeviceCard({
    super.key,
    required this.device,
    this.onConnect,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onSecondaryTapUp: (d) => _showContextMenu(context, d.globalPosition),
      child: InkWell(
        onTap: onConnect,
        borderRadius: BorderRadius.circular(MyTheme.radiusSmall),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(MyTheme.radiusSmall),
            border: device.colorLabel != null
                ? Border(
                    left: BorderSide(
                      color: _parseColor(device.colorLabel!),
                      width: 3,
                    ),
                  )
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 42,
                child: Row(
                  children: [
                    _StatusDot(device.status, device.lastSeen),
                    const SizedBox(width: 10),
                    _PlatformIcon(device.platform),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            device.displayName,
                            style: const TextStyle(fontSize: 15),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            device.alias != null
                                ? device.remoteId
                                : formatLastSeen(device.lastSeen, device.status),
                            style: TextStyle(
                              fontSize: 13,
                              // Numbers (IDs) get a slightly heavier weight +
                              // tabular figures so they're easy to scan/compare.
                              fontFeatures: const [FontFeature.tabularFigures()],
                              fontWeight: device.alias != null
                                  ? FontWeight.w500
                                  : FontWeight.normal,
                              color: Theme.of(context).textTheme.bodySmall?.color,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    if (device.isPinned)
                      Icon(CupertinoIcons.pin_fill,
                          size: 15, color: MyTheme.color(context).statusWarning),
                    if (device.isFavorite)
                      const Icon(CupertinoIcons.star_fill,
                          size: 15, color: Colors.amber),
                    _ConnectButton(device: device, onConnect: onConnect),
                  ],
                ),
              ),
              if (device.tags.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6, left: 26),
                  child: _InlineTagChips(tags: device.tags),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showContextMenu(BuildContext context, Offset position) async {
    final ctrl = DirectoryController.to;
    final result = await showMenu<_DeviceAction>(
      context: context,
      position: RelativeRect.fromLTRB(
          position.dx, position.dy, position.dx, position.dy),
      items: [
        PopupMenuItem(
          value: _DeviceAction.connect,
          child: const ListTile(
            dense: true,
            leading: Icon(CupertinoIcons.desktopcomputer, size: 18),
            title: Text('Connect', style: TextStyle(fontSize: 15)),
          ),
        ),
        PopupMenuItem(
          value: _DeviceAction.viewInfo,
          child: const ListTile(
            dense: true,
            leading: Icon(CupertinoIcons.info, size: 18),
            title: Text('Info & Notes', style: TextStyle(fontSize: 15)),
          ),
        ),
        PopupMenuItem(
          value: _DeviceAction.chatHistory,
          child: const ListTile(
            dense: true,
            leading: Icon(CupertinoIcons.chat_bubble, size: 18),
            title: Text('Chat history', style: TextStyle(fontSize: 15)),
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: _DeviceAction.edit,
          child: const ListTile(
            dense: true,
            leading: Icon(CupertinoIcons.pencil, size: 18),
            title: Text('Edit', style: TextStyle(fontSize: 15)),
          ),
        ),
        PopupMenuItem(
          value: _DeviceAction.move,
          child: const ListTile(
            dense: true,
            leading: Icon(Icons.drive_file_move, size: 18),
            title: Text('Move to folder', style: TextStyle(fontSize: 15)),
          ),
        ),
        PopupMenuItem(
          value: _DeviceAction.colorLabel,
          child: ListTile(
            dense: true,
            leading: CircleAvatar(
              radius: 9,
              backgroundColor: device.colorLabel != null
                  ? _parseColor(device.colorLabel!)
                  : Colors.grey.shade300,
            ),
            title: const Text('Color label', style: TextStyle(fontSize: 15)),
          ),
        ),
        PopupMenuItem(
          value: _DeviceAction.toggleFavorite,
          child: ListTile(
            dense: true,
            leading: Icon(
              device.isFavorite ? CupertinoIcons.star_fill : CupertinoIcons.star,
              size: 18,
              color: device.isFavorite ? Colors.amber : null,
            ),
            title: Text(device.isFavorite ? 'Remove from favorites' : 'Add to favorites',
                style: const TextStyle(fontSize: 15)),
          ),
        ),
        PopupMenuItem(
          value: _DeviceAction.togglePin,
          child: ListTile(
            dense: true,
            leading: Icon(
              device.isPinned ? CupertinoIcons.pin_fill : CupertinoIcons.pin,
              size: 18,
              color: device.isPinned ? MyTheme.color(context).statusWarning : null,
            ),
            title: Text(device.isPinned ? 'Unpin' : 'Pin to top',
                style: const TextStyle(fontSize: 15)),
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: _DeviceAction.delete,
          child: ListTile(
            dense: true,
            leading: Icon(CupertinoIcons.trash,
                size: 18, color: MyTheme.color(context).statusError),
            title: Text('Remove',
                style: TextStyle(
                    fontSize: 15, color: MyTheme.color(context).statusError)),
          ),
        ),
      ],
    );

    if (!context.mounted || result == null) return;
    switch (result) {
      case _DeviceAction.connect:
        onConnect?.call();
      case _DeviceAction.viewInfo:
        await Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => GdDeviceDetailPage(device: device)),
        );
      case _DeviceAction.chatHistory:
        await Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => GdChatHistoryPage(device: device)),
        );
      case _DeviceAction.edit:
        await showEditDeviceDialog(context, device);
      case _DeviceAction.move:
        await showMoveDeviceDialog(context, device);
      case _DeviceAction.colorLabel:
        await showColorLabelDialog(context, device);
      case _DeviceAction.toggleFavorite:
        await ctrl.toggleFavorite(device);
      case _DeviceAction.togglePin:
        await ctrl.togglePin(device);
      case _DeviceAction.delete:
        await showDeleteDeviceDialog(context, device);
    }
  }

  static Color _parseColor(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return Colors.blue;
    }
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────

class _StatusDot extends StatelessWidget {
  final GdDeviceStatus status;
  final String? lastSeen;
  const _StatusDot(this.status, this.lastSeen);

  @override
  Widget build(BuildContext context) {
    final label = statusLabel(status);
    final seen = formatLastSeen(lastSeen, status);
    return Tooltip(
      message: '$label\nLast seen: $seen',
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _color(context),
        ),
      ),
    );
  }

  Color _color(BuildContext context) {
    final tokens = MyTheme.color(context);
    switch (status) {
      case GdDeviceStatus.online:
        return tokens.statusOnline!;
      case GdDeviceStatus.busy:
        return tokens.statusWarning!;
      case GdDeviceStatus.connecting:
        return Theme.of(context).colorScheme.secondary;
      case GdDeviceStatus.offline:
        return tokens.statusOffline!;
      case GdDeviceStatus.unknown:
        return tokens.statusOffline!.withOpacity(0.5);
    }
  }
}

class _PlatformIcon extends StatelessWidget {
  final String? platform;
  const _PlatformIcon(this.platform);

  @override
  Widget build(BuildContext context) {
    final p = platform?.toLowerCase() ?? '';
    IconData icon;
    if (p.contains('windows')) {
      icon = Icons.window;
    } else if (p.contains('mac') || p.contains('darwin')) {
      icon = Icons.laptop_mac;
    } else if (p.contains('linux')) {
      icon = Icons.computer;
    } else if (p.contains('android')) {
      icon = Icons.phone_android;
    } else {
      icon = Icons.devices;
    }
    return Icon(icon, size: 16, color: Theme.of(context).textTheme.bodySmall?.color);
  }
}

class _InlineTagChips extends StatelessWidget {
  final List<String> tags;
  const _InlineTagChips({required this.tags});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.secondary;
    return Align(
      alignment: Alignment.centerLeft,
      child: Wrap(
        spacing: 4,
        runSpacing: 2,
        children: tags
            .map((t) => Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    t,
                    style: TextStyle(
                        fontSize: 11,
                        color: color,
                        fontWeight: FontWeight.w600),
                  ),
                ))
            .toList(),
      ),
    );
  }
}

class _ConnectButton extends StatefulWidget {
  final GdDevice device;
  final VoidCallback? onConnect;
  const _ConnectButton({required this.device, this.onConnect});

  @override
  State<_ConnectButton> createState() => _ConnectButtonState();
}

class _ConnectButtonState extends State<_ConnectButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: _hovered ? 1.0 : 0.0,
        child: IconButton(
          icon: const Icon(CupertinoIcons.play_arrow_solid, size: 18),
          tooltip: 'Connect',
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
          onPressed: widget.onConnect,
        ),
      ),
    );
  }
}

enum _DeviceAction {
  connect,
  viewInfo,
  chatHistory,
  edit,
  move,
  colorLabel,
  toggleFavorite,
  togglePin,
  delete,
}
