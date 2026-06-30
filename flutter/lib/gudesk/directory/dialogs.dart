import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'directory_controller.dart';
import 'models.dart';

// ── Create / Rename Directory ─────────────────────────────────────────────

Future<void> showCreateDirectoryDialog(
  BuildContext context, {
  int? parentId,
  String? parentName,
}) async {
  final ctrl = DirectoryController.to;
  final nameCtrl = TextEditingController();
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(parentName != null ? 'New folder in $parentName' : 'New folder'),
      content: _NameField(controller: nameCtrl, hint: 'Folder name'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        FilledButton(
          onPressed: () async {
            final name = nameCtrl.text.trim();
            if (name.isEmpty) return;
            await ctrl.createDirectory(name, parentId: parentId);
            if (ctx.mounted) Navigator.pop(ctx);
          },
          child: const Text('Create'),
        ),
      ],
    ),
  );
}

Future<void> showRenameDirectoryDialog(
  BuildContext context,
  GdDirectory dir,
) async {
  final ctrl = DirectoryController.to;
  final nameCtrl = TextEditingController(text: dir.name);
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Rename folder'),
      content: _NameField(controller: nameCtrl, hint: 'Folder name'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        FilledButton(
          onPressed: () async {
            final name = nameCtrl.text.trim();
            if (name.isEmpty) return;
            await ctrl.renameDirectory(dir, name);
            if (ctx.mounted) Navigator.pop(ctx);
          },
          child: const Text('Rename'),
        ),
      ],
    ),
  );
}

Future<void> showDeleteDirectoryDialog(
  BuildContext context,
  GdDirectory dir,
) async {
  final ctrl = DirectoryController.to;
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Delete folder'),
      content: Text(
        'Delete "${dir.name}" and all sub-folders?\n\n'
        'Devices inside will be moved to Unassigned.',
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Colors.red),
          onPressed: () async {
            await ctrl.deleteDirectory(dir);
            if (ctx.mounted) Navigator.pop(ctx);
          },
          child: const Text('Delete'),
        ),
      ],
    ),
  );
}

// ── Add Device ────────────────────────────────────────────────────────────

Future<void> showAddDeviceDialog(
  BuildContext context, {
  int? directoryId,
}) async {
  final ctrl = DirectoryController.to;
  final idCtrl = TextEditingController();
  final aliasCtrl = TextEditingController();
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Add device'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _NameField(controller: idCtrl, hint: 'e.g. 123456789', label: 'Remote ID'),
          const SizedBox(height: 12),
          _NameField(
            controller: aliasCtrl,
            hint: 'Optional',
            label: 'Alias',
            required: false,
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        FilledButton(
          onPressed: () async {
            final remoteId = idCtrl.text.trim();
            if (remoteId.isEmpty) return;
            final now = DateTime.now();
            await ctrl.addDevice(GdDevice(
              remoteId: remoteId,
              alias: aliasCtrl.text.trim().isEmpty ? null : aliasCtrl.text.trim(),
              directoryId: directoryId,
              createdAt: now,
              updatedAt: now,
            ));
            if (ctx.mounted) Navigator.pop(ctx);
          },
          child: const Text('Add'),
        ),
      ],
    ),
  );
}

// ── Edit Device ───────────────────────────────────────────────────────────

Future<void> showEditDeviceDialog(
  BuildContext context,
  GdDevice device,
) async {
  final ctrl = DirectoryController.to;
  final aliasCtrl = TextEditingController(text: device.alias ?? '');
  final notesCtrl = TextEditingController(text: device.notes ?? '');
  final tagCtrl = TextEditingController();
  var tags = List<String>.from(device.tags);

  await showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: Text('Edit ${device.displayName}'),
        content: SizedBox(
          width: 360,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _NameField(
                  controller: aliasCtrl,
                  hint: device.remoteId,
                  label: 'Alias',
                  required: false,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Notes',
                    border: OutlineInputBorder(),
                    hintText: 'Markdown supported',
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 12),
                const Text('Tags', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: tags
                      .map((t) => Chip(
                            label: Text(t),
                            onDeleted: () => setState(() => tags.remove(t)),
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ))
                      .toList(),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: tagCtrl,
                        decoration: const InputDecoration(
                          hintText: 'Add tag...',
                          isDense: true,
                        ),
                        onSubmitted: (v) {
                          final tag = v.trim();
                          if (tag.isNotEmpty && !tags.contains(tag)) {
                            setState(() => tags.add(tag));
                            tagCtrl.clear();
                          }
                        },
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add, size: 20),
                      onPressed: () {
                        final tag = tagCtrl.text.trim();
                        if (tag.isNotEmpty && !tags.contains(tag)) {
                          setState(() => tags.add(tag));
                          tagCtrl.clear();
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final alias = aliasCtrl.text.trim().isEmpty ? null : aliasCtrl.text.trim();
              final notes = notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim();
              final updated = device.copyWith(alias: alias, notes: notes, tags: tags);
              await ctrl.updateDevice(updated);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    ),
  );
}

// ── Move Device ───────────────────────────────────────────────────────────

Future<void> showMoveDeviceDialog(
  BuildContext context,
  GdDevice device,
) async {
  final ctrl = DirectoryController.to;
  int? selectedId = device.directoryId;
  await showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: Text('Move ${device.displayName}'),
        content: SizedBox(
          width: 320,
          height: 320,
          child: RadioGroup<int?>(
            groupValue: selectedId,
            onChanged: (v) => setState(() => selectedId = v),
            child: ListView(
              children: [
                RadioListTile<int?>(
                  title: const Text('Unassigned'),
                  value: null,
                ),
                ...ctrl.directories.map((d) => RadioListTile<int?>(
                      title: Text(_directoryPath(ctrl, d)),
                      value: d.id,
                    )),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              await ctrl.moveDevice(device, selectedId);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Move'),
          ),
        ],
      ),
    ),
  );
}

// ── Color Label ───────────────────────────────────────────────────────────

Future<void> showColorLabelDialog(
  BuildContext context,
  GdDevice device,
) async {
  final ctrl = DirectoryController.to;
  Color picked = Colors.blue;
  if (device.colorLabel != null) {
    try {
      picked = Color(int.parse(device.colorLabel!.replaceFirst('#', '0xFF')));
    } catch (_) {}
  }

  await showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: const Text('Color label'),
        content: ColorPicker(
          color: picked,
          onColorChanged: (c) => setState(() => picked = c),
          width: 40,
          height: 40,
          borderRadius: 4,
          spacing: 5,
          runSpacing: 5,
          wheelDiameter: 165,
          heading: Text('Select color', style: Theme.of(ctx).textTheme.titleSmall),
          subheading: Text('Select shade', style: Theme.of(ctx).textTheme.titleSmall),
          pickersEnabled: const {
            ColorPickerType.primary: true,
            ColorPickerType.accent: false,
            ColorPickerType.wheel: true,
          },
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await ctrl.setColorLabel(device, null);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Clear', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final hex = '#${picked.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
              await ctrl.setColorLabel(device, hex);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    ),
  );
}

// ── Delete Device ─────────────────────────────────────────────────────────

Future<void> showDeleteDeviceDialog(
  BuildContext context,
  GdDevice device,
) async {
  final ctrl = DirectoryController.to;
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Remove device'),
      content: Text('Remove "${device.displayName}" from directory?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Colors.red),
          onPressed: () async {
            await ctrl.deleteDevice(device);
            if (ctx.mounted) Navigator.pop(ctx);
          },
          child: const Text('Remove'),
        ),
      ],
    ),
  );
}

// ── Internal helpers ──────────────────────────────────────────────────────

String _directoryPath(DirectoryController ctrl, GdDirectory dir) {
  final parts = <String>[dir.name];
  int? pid = dir.parentId;
  while (pid != null) {
    final parent = ctrl.directories.cast<GdDirectory?>().firstWhere(
          (d) => d?.id == pid,
          orElse: () => null,
        );
    if (parent == null) break;
    parts.insert(0, parent.name);
    pid = parent.parentId;
  }
  return parts.join(' / ');
}

class _NameField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final String? label;
  final bool required;

  const _NameField({
    required this.controller,
    required this.hint,
    this.label,
    this.required = true,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      autofocus: label == null || label == 'Remote ID' || label == 'Folder name',
      inputFormatters: [LengthLimitingTextInputFormatter(120)],
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
      ),
    );
  }
}
