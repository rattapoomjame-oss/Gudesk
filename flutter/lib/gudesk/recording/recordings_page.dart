import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'models.dart';
import 'recording_controller.dart';

class RecordingsPage extends StatefulWidget {
  const RecordingsPage({super.key});

  @override
  State<RecordingsPage> createState() => _RecordingsPageState();
}

class _RecordingsPageState extends State<RecordingsPage> {
  late final GdRecordingController _ctrl;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (!Get.isRegistered<GdRecordingController>(tag: 'gudesk_recording')) {
      Get.put(GdRecordingController(),
          tag: 'gudesk_recording', permanent: true);
    }
    _ctrl = GdRecordingController.to;
    _searchCtrl.text = _ctrl.searchQuery.value;
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recordings'),
        centerTitle: false,
        actions: [
          Obx(() => _ctrl.isScanning.value
              ? const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 14),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Rescan recording folder',
                  onPressed: _ctrl.rescan,
                )),
        ],
      ),
      body: Column(
        children: [
          _SearchBar(
            controller: _searchCtrl,
            onChanged: (q) => _ctrl.searchQuery.value = q,
          ),
          _RetentionRow(ctrl: _ctrl),
          const Divider(height: 1),
          Expanded(child: _RecordingsList(ctrl: _ctrl)),
        ],
      ),
    );
  }
}

// ── Search bar ────────────────────────────────────────────────────────────

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  const _SearchBar({required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: 'Search by device ID or filename…',
          prefixIcon: const Icon(Icons.search, size: 18),
          isDense: true,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          contentPadding: const EdgeInsets.symmetric(vertical: 8),
          suffixIcon: controller.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 16),
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                  },
                )
              : null,
        ),
      ),
    );
  }
}

// ── Retention policy row ──────────────────────────────────────────────────

class _RetentionRow extends StatefulWidget {
  final GdRecordingController ctrl;
  const _RetentionRow({required this.ctrl});

  @override
  State<_RetentionRow> createState() => _RetentionRowState();
}

class _RetentionRowState extends State<_RetentionRow> {
  late final TextEditingController _tc;

  @override
  void initState() {
    super.initState();
    _tc = TextEditingController(
        text: widget.ctrl.retentionDays.value.toString());
  }

  @override
  void dispose() {
    _tc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.auto_delete_outlined, size: 16, color: Colors.grey),
          const SizedBox(width: 6),
          Text('Keep for', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(width: 6),
          SizedBox(
            width: 52,
            height: 28,
            child: TextField(
              controller: _tc,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13),
              decoration: const InputDecoration(
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                border: OutlineInputBorder(),
              ),
              onSubmitted: (v) {
                final d = int.tryParse(v);
                if (d != null && d > 0) widget.ctrl.setRetentionDays(d);
              },
            ),
          ),
          const SizedBox(width: 6),
          Text('days', style: Theme.of(context).textTheme.bodySmall),
          const Spacer(),
          TextButton.icon(
            onPressed: widget.ctrl.applyRetentionNow,
            icon: const Icon(Icons.cleaning_services, size: 14),
            label:
                const Text('Apply now', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

// ── Recordings list ───────────────────────────────────────────────────────

class _RecordingsList extends StatelessWidget {
  final GdRecordingController ctrl;
  const _RecordingsList({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final list = ctrl.filtered;
      if (list.isEmpty) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.video_library_outlined,
                  size: 52, color: Theme.of(context).disabledColor),
              const SizedBox(height: 10),
              Text(
                ctrl.recordings.isEmpty
                    ? 'No recordings yet'
                    : 'No results for "${ctrl.searchQuery.value}"',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        );
      }
      return ListView.separated(
        itemCount: list.length,
        separatorBuilder: (_, __) =>
            const Divider(height: 1, indent: 52),
        itemBuilder: (ctx, i) =>
            _RecordingCard(recording: list[i], ctrl: ctrl),
      );
    });
  }
}

// ── Recording card ────────────────────────────────────────────────────────

class _RecordingCard extends StatelessWidget {
  final GdRecording recording;
  final GdRecordingController ctrl;
  const _RecordingCard({required this.recording, required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final r = recording;
    final missing = !r.existsOnDisk;
    return InkWell(
      onTap: missing ? null : () => ctrl.openRecording(r),
      onSecondaryTapUp: (d) =>
          _showContextMenu(context, d.globalPosition),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Icon(
              r.filename.endsWith('.mp4')
                  ? Icons.video_file
                  : Icons.video_library,
              size: 30,
              color: missing
                  ? Theme.of(context).disabledColor
                  : Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    r.remoteId,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    _dateLabel(r.createdAt),
                    style: TextStyle(
                        fontSize: 11,
                        color:
                            Theme.of(context).textTheme.bodySmall?.color),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(r.displaySize,
                    style: const TextStyle(fontSize: 11)),
                if (missing)
                  Text(
                    'File missing',
                    style: TextStyle(
                        fontSize: 10,
                        color: Theme.of(context).colorScheme.error),
                  ),
              ],
            ),
            const SizedBox(width: 4),
            _HoverActions(recording: r, ctrl: ctrl),
          ],
        ),
      ),
    );
  }

  Future<void> _showContextMenu(
      BuildContext context, Offset position) async {
    final r = recording;
    final result = await showMenu<_RecAction>(
      context: context,
      position:
          RelativeRect.fromLTRB(position.dx, position.dy, position.dx, position.dy),
      items: [
        if (r.existsOnDisk)
          const PopupMenuItem(
            value: _RecAction.play,
            child: ListTile(
              dense: true,
              leading: Icon(Icons.play_circle_outline, size: 18),
              title: Text('Play'),
            ),
          ),
        PopupMenuItem(
          value: _RecAction.reveal,
          child: ListTile(
            dense: true,
            leading: Icon(
              Platform.isMacOS ? Icons.folder_open : Icons.folder,
              size: 18,
            ),
            title: Text(
              Platform.isMacOS ? 'Reveal in Finder' : 'Show in Explorer',
            ),
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: _RecAction.delete,
          child: ListTile(
            dense: true,
            leading:
                Icon(Icons.delete_outline, size: 18, color: Colors.red),
            title:
                Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ),
      ],
    );
    if (!context.mounted || result == null) return;
    switch (result) {
      case _RecAction.play:
        await ctrl.openRecording(r);
      case _RecAction.reveal:
        await ctrl.revealInFinder(r);
      case _RecAction.delete:
        await _confirmDelete(context);
    }
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete recording?'),
        content: Text(
          'This will permanently delete\n"${recording.baseName}"\nfrom disk.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) await ctrl.deleteRecording(recording);
  }

  static String _dateLabel(DateTime dt) =>
      '${dt.year}-'
      '${dt.month.toString().padLeft(2, '0')}-'
      '${dt.day.toString().padLeft(2, '0')}  '
      '${dt.hour.toString().padLeft(2, '0')}:'
      '${dt.minute.toString().padLeft(2, '0')}';
}

// ── Hover action buttons ──────────────────────────────────────────────────

class _HoverActions extends StatefulWidget {
  final GdRecording recording;
  final GdRecordingController ctrl;
  const _HoverActions({required this.recording, required this.ctrl});

  @override
  State<_HoverActions> createState() => _HoverActionsState();
}

class _HoverActionsState extends State<_HoverActions> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedOpacity(
        opacity: _hovered ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 120),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.recording.existsOnDisk)
              IconButton(
                icon: const Icon(Icons.play_circle_outline, size: 18),
                tooltip: 'Play',
                padding: EdgeInsets.zero,
                constraints:
                    const BoxConstraints(minWidth: 28, minHeight: 28),
                onPressed: () =>
                    widget.ctrl.openRecording(widget.recording),
              ),
            IconButton(
              icon: const Icon(Icons.folder_open, size: 16),
              tooltip:
                  Platform.isMacOS ? 'Reveal in Finder' : 'Show in Explorer',
              padding: EdgeInsets.zero,
              constraints:
                  const BoxConstraints(minWidth: 28, minHeight: 28),
              onPressed: () =>
                  widget.ctrl.revealInFinder(widget.recording),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline,
                  size: 16, color: Colors.red),
              tooltip: 'Delete',
              padding: EdgeInsets.zero,
              constraints:
                  const BoxConstraints(minWidth: 28, minHeight: 28),
              onPressed: () => _confirmDelete(context),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete recording?'),
        content: Text(
          'This will permanently delete\n"${widget.recording.baseName}"\nfrom disk.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style:
                FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await widget.ctrl.deleteRecording(widget.recording);
    }
  }
}

enum _RecAction { play, reveal, delete }
