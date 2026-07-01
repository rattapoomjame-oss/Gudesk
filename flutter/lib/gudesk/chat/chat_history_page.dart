import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../directory/models.dart';
import 'chat_db.dart';
import 'chat_models.dart';
import 'chat_persister.dart';

class GdChatHistoryPage extends StatefulWidget {
  final GdDevice device;
  const GdChatHistoryPage({super.key, required this.device});

  @override
  State<GdChatHistoryPage> createState() => _GdChatHistoryPageState();
}

class _GdChatHistoryPageState extends State<GdChatHistoryPage> {
  List<GdChatMessage> _messages = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final msgs = await GdChatDb.getHistory(widget.device.remoteId);
    if (mounted) setState(() { _messages = msgs; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Chat — ${widget.device.displayName}'),
        actions: [
          Tooltip(
            message: 'Operator name (shown in exports)',
            child: IconButton(
              icon: const Icon(Icons.badge_outlined),
              onPressed: _showOperatorNameDialog,
            ),
          ),
          Tooltip(
            message: 'Export chat log',
            child: PopupMenuButton<_ExportFormat>(
              icon: const Icon(Icons.download_outlined),
              onSelected: _export,
              itemBuilder: (_) => const [
                PopupMenuItem(value: _ExportFormat.text, child: Text('Export as .txt')),
                PopupMenuItem(value: _ExportFormat.csv,  child: Text('Export as .csv')),
              ],
            ),
          ),
          Tooltip(
            message: 'Clear history',
            child: IconButton(
              icon: const Icon(Icons.delete_sweep_outlined),
              onPressed: _messages.isEmpty ? null : _confirmClear,
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _messages.isEmpty
              ? _EmptyState(remoteId: widget.device.displayName)
              : _MessageList(
                  messages: _messages,
                  remoteId: widget.device.displayName,
                ),
    );
  }

  Future<void> _showOperatorNameDialog() async {
    final current = GdChatPersister.instance.operatorName;
    final ctrl = TextEditingController(text: current);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Operator name'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your name as it appears in exported chat logs.',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'e.g. Alice (Support)',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result != null) {
      await GdChatPersister.instance.setOperatorName(result);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Operator name set to "${result.isNotEmpty ? result : '(empty)'}"')),
        );
      }
    }
  }

  Future<void> _export(_ExportFormat fmt) async {
    final content = fmt == _ExportFormat.text
        ? GdChatExport.toText(_messages, remoteId: widget.device.displayName)
        : GdChatExport.toCsv(_messages);
    final ext = fmt == _ExportFormat.text ? 'txt' : 'csv';
    final name = 'gudesk-chat-${widget.device.remoteId}-${DateTime.now().millisecondsSinceEpoch}.$ext';

    try {
      final dir = await _saveDir();
      final file = File('${dir.path}/$name');
      await file.writeAsString(content, flush: true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Saved to ${file.path}'),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    }
  }

  Future<Directory> _saveDir() async {
    if (Platform.isMacOS) {
      final home = Platform.environment['HOME'] ?? '';
      final dl = Directory('$home/Downloads');
      if (await dl.exists()) return dl;
    }
    return getApplicationDocumentsDirectory();
  }

  Future<void> _confirmClear() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear chat history?'),
        content: Text(
          'Delete all ${_messages.length} stored messages for ${widget.device.displayName}? '
          'This cannot be undone.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await GdChatDb.deleteHistory(widget.device.remoteId);
      if (mounted) setState(() => _messages = []);
    }
  }
}

// ── Message list ──────────────────────────────────────────────────────────

class _MessageList extends StatelessWidget {
  final List<GdChatMessage> messages;
  final String remoteId;
  const _MessageList({required this.messages, required this.remoteId});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: messages.length,
      itemBuilder: (ctx, i) {
        final msg = messages[i];
        final showDate = i == 0 || !_sameDay(messages[i - 1].createdAt, msg.createdAt);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (showDate) _DateChip(msg.createdAt),
            _Bubble(message: msg, remoteId: remoteId),
          ],
        );
      },
    );
  }

  static bool _sameDay(DateTime a, DateTime b) {
    final la = a.toLocal();
    final lb = b.toLocal();
    return la.year == lb.year && la.month == lb.month && la.day == lb.day;
  }
}

class _DateChip extends StatelessWidget {
  final DateTime date;
  const _DateChip(this.date);

  @override
  Widget build(BuildContext context) {
    final d = date.toLocal();
    final label =
        '${d.year}-${_p(d.month)}-${_p(d.day)}';
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 12),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Theme.of(context).textTheme.bodySmall?.color,
          ),
        ),
      ),
    );
  }

  static String _p(int n) => n.toString().padLeft(2, '0');
}

class _Bubble extends StatelessWidget {
  final GdChatMessage message;
  final String remoteId;
  const _Bubble({required this.message, required this.remoteId});

  @override
  Widget build(BuildContext context) {
    final isOut = message.isOutgoing;
    final scheme = Theme.of(context).colorScheme;
    final bgColor = isOut ? scheme.primary : scheme.surfaceContainerHighest;
    final textColor = isOut ? scheme.onPrimary : scheme.onSurface;
    final d = message.createdAt.toLocal();
    final ts = '${_p(d.hour)}:${_p(d.minute)}';
    final who = isOut
        ? (message.sender.isNotEmpty ? message.sender : 'Me')
        : remoteId;

    return Align(
      alignment: isOut ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 3),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(12),
              topRight: const Radius.circular(12),
              bottomLeft: Radius.circular(isOut ? 12 : 2),
              bottomRight: Radius.circular(isOut ? 2 : 12),
            ),
          ),
          child: Column(
            crossAxisAlignment:
                isOut ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Text(
                who,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: textColor.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                message.text,
                style: TextStyle(fontSize: 13, color: textColor),
              ),
              const SizedBox(height: 2),
              Text(
                ts,
                style: TextStyle(
                  fontSize: 10,
                  color: textColor.withValues(alpha: 0.55),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _p(int n) => n.toString().padLeft(2, '0');
}

// ── Empty state ───────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final String remoteId;
  const _EmptyState({required this.remoteId});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.chat_bubble_outline,
              size: 48, color: Theme.of(context).disabledColor),
          const SizedBox(height: 12),
          Text(
            'No chat history with $remoteId',
            style: TextStyle(color: Theme.of(context).disabledColor),
          ),
          const SizedBox(height: 6),
          const Text(
            'Messages are saved automatically when you chat during a session.',
            style: TextStyle(fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

enum _ExportFormat { text, csv }
