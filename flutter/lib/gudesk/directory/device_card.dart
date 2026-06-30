import 'package:flutter/material.dart';

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
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
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
                height: 32,
                child: Row(
                  children: [
                    _StatusDot(device.status, device.lastSeen),
                    const SizedBox(width: 8),
                    _PlatformIcon(device.platform),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            device.displayName,
                            style: const TextStyle(fontSize: 13),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            device.alias != null
                                ? device.remoteId
                                : formatLastSeen(device.lastSeen, device.status),
                            style: TextStyle(
                              fontSize: 10,
                              color: Theme.of(context).textTheme.bodySmall?.color,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    if (device.isPinned)
                      const Icon(Icons.push_pin, size: 13, color: Colors.orange),
                    if (device.isFavorite)
                      const Icon(Icons.star, size: 13, color: Colors.amber),
                    _ConnectButton(device: device, onConnect: onConnect),
                  ],
                ),
              ),
              if (device.tags.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4, left: 24),
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
            leading: Icon(Icons.desktop_windows, size: 18),
            title: Text('Connect'),
          ),
        ),
        PopupMenuItem(
          value: _DeviceAction.viewInfo,
          child: const ListTile(
            dense: true,
            leading: Icon(Icons.info_outline, size: 18),
            title: Text('Info & Notes'),
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: _DeviceAction.edit,
          child: const ListTile(
            dense: true,
            leading: Icon(Icons.edit, size: 18),
            title: Text('Edit'),
          ),
        ),
        PopupMenuItem(
          value: _DeviceAction.move,
          child: const ListTile(
            dense: true,
            leading: Icon(Icons.drive_file_move, size: 18),
            title: Text('Move to folder'),
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
            title: const Text('Color label'),
          ),
        ),
        PopupMenuItem(
          value: _DeviceAction.toggleFavorite,
          child: ListTile(
            dense: true,
            leading: Icon(
              device.isFavorite ? Icons.star : Icons.star_border,
              size: 18,
              color: device.isFavorite ? Colors.amber : null,
            ),
            title: Text(device.isFavorite ? 'Remove from favorites' : 'Add to favorites'),
          ),
        ),
        PopupMenuItem(
          value: _DeviceAction.togglePin,
          child: ListTile(
            dense: true,
            leading: Icon(
              Icons.push_pin,
              size: 18,
              color: device.isPinned ? Colors.orange : null,
            ),
            title: Text(device.isPinned ? 'Unpin' : 'Pin to top'),
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: _DeviceAction.delete,
          child: const ListTile(
            dense: true,
            leading: Icon(Icons.delete_outline, size: 18, color: Colors.red),
            title: Text('Remove', style: TextStyle(color: Colors.red)),
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
          color: _color,
        ),
      ),
    );
  }

  Color get _color {
    switch (status) {
      case GdDeviceStatus.online:
        return const Color(0xFF4CAF50);
      case GdDeviceStatus.busy:
        return Colors.orange;
      case GdDeviceStatus.connecting:
        return Colors.blue;
      case GdDeviceStatus.offline:
        return Colors.grey;
      case GdDeviceStatus.unknown:
        return Colors.grey.shade400;
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
                        fontSize: 9,
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
          icon: const Icon(Icons.play_circle_outline, size: 18),
          tooltip: 'Connect',
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          onPressed: widget.onConnect,
        ),
      ),
    );
  }
}

enum _DeviceAction {
  connect,
  viewInfo,
  edit,
  move,
  colorLabel,
  toggleFavorite,
  togglePin,
  delete,
}
