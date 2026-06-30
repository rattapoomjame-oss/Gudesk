import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../directory/directory_controller.dart';
import '../directory/models.dart';
import '../status/formatting.dart';

/// Full-screen panel showing device system info, notes, and tag management.
/// Pushed via [Navigator.push] from the device card context menu.
class GdDeviceDetailPage extends StatefulWidget {
  final GdDevice device;
  const GdDeviceDetailPage({super.key, required this.device});

  @override
  State<GdDeviceDetailPage> createState() => _GdDeviceDetailPageState();
}

class _GdDeviceDetailPageState extends State<GdDeviceDetailPage> {
  late GdDevice _device;
  late final TextEditingController _notesCtrl;
  bool _notesDirty = false;

  @override
  void initState() {
    super.initState();
    _device = widget.device;
    _notesCtrl = TextEditingController(text: _device.notes ?? '');
    _notesCtrl.addListener(() {
      final changed = _notesCtrl.text != (_device.notes ?? '');
      if (changed != _notesDirty) setState(() => _notesDirty = changed);
    });
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_device.displayName),
        actions: [
          if (_notesDirty)
            TextButton.icon(
              icon: const Icon(Icons.save),
              label: const Text('Save notes'),
              onPressed: _saveNotes,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SectionHeader('System info'),
          _InfoCard(device: _device),
          const SizedBox(height: 16),
          _SectionHeader('Tags'),
          _TagsCard(
            device: _device,
            onChanged: (updated) => setState(() => _device = updated),
          ),
          const SizedBox(height: 16),
          _SectionHeader('Notes'),
          _NotesCard(controller: _notesCtrl),
        ],
      ),
    );
  }

  Future<void> _saveNotes() async {
    final ctrl = DirectoryController.to;
    final updated = _device.copyWith(notes: _notesCtrl.text);
    await ctrl.updateDevice(updated);
    setState(() {
      _device = updated;
      _notesDirty = false;
    });
  }
}

// ── Section header ────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.primary,
            ),
      ),
    );
  }
}

// ── System info card ──────────────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  final GdDevice device;
  const _InfoCard({required this.device});

  @override
  Widget build(BuildContext context) {
    final rows = <(String, String)>[
      ('Remote ID', device.remoteId),
      if ((device.alias ?? '').isNotEmpty) ('Alias', device.alias!),
      ('Status', statusLabel(device.status)),
      ('Last seen', formatLastSeen(device.lastSeen, device.status)),
      if (device.hostname.isNotEmpty) ('Hostname', device.hostname),
      if ((device.platform ?? '').isNotEmpty) ('Platform', device.platform!),
      if ((device.version ?? '').isNotEmpty) ('Version', device.version!),
      if (device.osDetail.isNotEmpty) ('OS detail', device.osDetail),
      if (device.ipLast.isNotEmpty) ('Last IP', device.ipLast),
    ];

    return Card(
      margin: EdgeInsets.zero,
      child: Column(
        children: [
          for (int i = 0; i < rows.length; i++) ...[
            if (i > 0) const Divider(height: 1, indent: 12, endIndent: 12),
            _InfoRow(label: rows[i].$1, value: rows[i].$2),
          ],
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onLongPress: () {
        Clipboard.setData(ClipboardData(text: value));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Copied "$value"'),
            duration: const Duration(seconds: 1),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 100,
              child: Text(
                label,
                style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).textTheme.bodySmall?.color),
              ),
            ),
            Expanded(
              child: Text(value,
                  style: const TextStyle(fontSize: 13,
                      fontWeight: FontWeight.w500)),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Tags card ─────────────────────────────────────────────────────────────

class _TagsCard extends StatelessWidget {
  final GdDevice device;
  final ValueChanged<GdDevice> onChanged;
  const _TagsCard({required this.device, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final tag in device.tags)
                  Chip(
                    label: Text(tag, style: const TextStyle(fontSize: 12)),
                    padding: EdgeInsets.zero,
                    labelPadding:
                        const EdgeInsets.symmetric(horizontal: 8),
                    deleteIcon:
                        const Icon(Icons.close, size: 14),
                    onDeleted: () => _removeTag(context, tag),
                  ),
                ActionChip(
                  avatar: const Icon(Icons.add, size: 14),
                  label: const Text('Add tag',
                      style: TextStyle(fontSize: 12)),
                  padding: EdgeInsets.zero,
                  labelPadding:
                      const EdgeInsets.symmetric(horizontal: 4),
                  onPressed: () => _addTag(context),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addTag(BuildContext context) async {
    final ctrl = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add tag'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            hintText: 'e.g. Production, CEO, Server…',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: const Text('Add')),
        ],
      ),
    );
    if (result == null || result.isEmpty || device.tags.contains(result)) {
      return;
    }
    final newTags = [...device.tags, result];
    final updated = device.copyWith(tags: newTags);
    await DirectoryController.to.updateTags(device, newTags);
    onChanged(updated);
  }

  Future<void> _removeTag(BuildContext context, String tag) async {
    final newTags = device.tags.where((t) => t != tag).toList();
    final updated = device.copyWith(tags: newTags);
    await DirectoryController.to.updateTags(device, newTags);
    onChanged(updated);
  }
}

// ── Notes card ────────────────────────────────────────────────────────────

class _NotesCard extends StatelessWidget {
  final TextEditingController controller;
  const _NotesCard({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: TextField(
          controller: controller,
          maxLines: null,
          minLines: 5,
          keyboardType: TextInputType.multiline,
          style: const TextStyle(fontSize: 13),
          decoration: InputDecoration(
            hintText: 'Device notes, credentials hints, maintenance log…',
            hintStyle: TextStyle(
                color: Theme.of(context).textTheme.bodySmall?.color,
                fontSize: 13),
            border: InputBorder.none,
          ),
        ),
      ),
    );
  }
}
