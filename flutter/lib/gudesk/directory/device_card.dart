import 'package:flutter/material.dart';

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
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 8),
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
          child: Row(
            children: [
              _StatusDot(device.status),
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
                    if (device.alias != null)
                      Text(
                        device.remoteId,
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
              if (device.tags.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: 2),
                  child: _TagBadge(count: device.tags.length),
                ),
              const SizedBox(width: 4),
              _ConnectButton(device: device, onConnect: onConnect),
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
  const _StatusDot(this.status);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _color,
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

class _TagBadge extends StatelessWidget {
  final int count;
  const _TagBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$count',
        style: TextStyle(
          fontSize: 9,
          color: Theme.of(context).colorScheme.secondary,
          fontWeight: FontWeight.w700,
        ),
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

enum _DeviceAction { connect, edit, move, colorLabel, toggleFavorite, togglePin, delete }
