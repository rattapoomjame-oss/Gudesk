import 'dart:async';
import 'dart:io';

import 'package:flutter_hbb/models/platform_model.dart';
import 'package:get/get.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'models.dart';
import 'recording_db.dart';

const _kRetentionKey = 'gudesk_recording_retention_days';
const _kDefaultRetentionDays = 30;
const _kRecordStatusEvent = 'record_status';
const _kHandlerName = 'gudesk_recording';

class GdRecordingController extends GetxController {
  static GdRecordingController get to =>
      Get.find(tag: 'gudesk_recording');

  final recordings = <GdRecording>[].obs;
  final searchQuery = ''.obs;
  final isScanning = false.obs;
  final retentionDays = _kDefaultRetentionDays.obs;

  List<GdRecording> get filtered {
    final q = searchQuery.value.toLowerCase().trim();
    if (q.isEmpty) return recordings;
    return recordings
        .where((r) =>
            r.remoteId.toLowerCase().contains(q) ||
            r.baseName.toLowerCase().contains(q))
        .toList();
  }

  @override
  void onInit() {
    super.onInit();
    platformFFI.registerEventHandler(
        _kRecordStatusEvent, _kHandlerName, _onRecordStatus);
    _loadRetentionDays();
    rescan().then((_) => _applyRetentionPolicy());
  }

  @override
  void onClose() {
    platformFFI.unregisterEventHandler(_kRecordStatusEvent, _kHandlerName);
    super.onClose();
  }

  // ── Event handler ─────────────────────────────────────────────────────────

  Future<void> _onRecordStatus(Map<String, dynamic> evt) async {
    if (evt['start'] == 'true') return;
    // Recording stopped — Rust finalizes the file, give it a moment.
    await Future.delayed(const Duration(milliseconds: 600));
    await rescan();
  }

  // ── Scanning ──────────────────────────────────────────────────────────────

  /// Public entry point: scan the recording directory and catalog new files.
  Future<void> rescan() => _scanAndCatalog();

  Future<void> _scanAndCatalog() async {
    if (isScanning.value) return;
    isScanning.value = true;
    try {
      final dir = await _recordingDir();
      if (dir == null || !dir.existsSync()) return;
      await _scanDir(dir);
      await _reload();
    } finally {
      isScanning.value = false;
    }
  }

  Future<void> _scanDir(Directory dir) async {
    await for (final entity in dir.list(recursive: true)) {
      if (entity is! File) continue;
      final ext = p.extension(entity.path).toLowerCase();
      if (ext != '.mp4' && ext != '.webm') continue;
      final rec = GdRecording.fromFile(entity.path);
      if (rec == null) continue;
      if (!await GdRecordingDb.existsByFilename(entity.path)) {
        await GdRecordingDb.insertRecording(rec);
      }
    }
  }

  Future<void> _reload() async {
    recordings.value = await GdRecordingDb.getAllRecordings();
  }

  // ── Retention policy ──────────────────────────────────────────────────────

  void _loadRetentionDays() {
    try {
      final raw = bind.getLocalFlutterOption(k: _kRetentionKey);
      retentionDays.value = int.tryParse(raw) ?? _kDefaultRetentionDays;
    } catch (_) {}
  }

  Future<void> setRetentionDays(int days) async {
    retentionDays.value = days;
    try {
      bind.setLocalFlutterOption(k: _kRetentionKey, v: days.toString());
    } catch (_) {}
    await _applyRetentionPolicy();
  }

  Future<void> applyRetentionNow() => _applyRetentionPolicy();

  Future<void> _applyRetentionPolicy() async {
    if (retentionDays.value <= 0) return;
    final cutoff =
        DateTime.now().subtract(Duration(days: retentionDays.value));
    for (final r in List.of(recordings)) {
      if (r.createdAt.isBefore(cutoff) && r.existsOnDisk) {
        try {
          await File(r.filename).delete();
        } catch (_) {}
      }
    }
    await GdRecordingDb.deleteRecordingsBefore(cutoff);
    await _reload();
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  Future<void> deleteRecording(GdRecording r) async {
    if (r.existsOnDisk) {
      try {
        await File(r.filename).delete();
      } catch (_) {}
    }
    if (r.id != null) await GdRecordingDb.deleteRecording(r.id!);
    recordings.remove(r);
  }

  Future<void> openRecording(GdRecording r) async {
    if (!r.existsOnDisk) return;
    if (Platform.isMacOS) {
      await Process.run('open', [r.filename]);
    } else if (Platform.isWindows) {
      await Process.run('cmd', ['/c', 'start', '', r.filename]);
    } else {
      await Process.run('xdg-open', [r.filename]);
    }
  }

  Future<void> revealInFinder(GdRecording r) async {
    if (Platform.isMacOS) {
      await Process.run('open', ['-R', r.existsOnDisk ? r.filename : p.dirname(r.filename)]);
    } else if (Platform.isWindows) {
      if (r.existsOnDisk) {
        await Process.run('explorer', ['/select,', r.filename]);
      } else {
        await Process.run('explorer', [p.dirname(r.filename)]);
      }
    } else {
      await Process.run('xdg-open', [p.dirname(r.filename)]);
    }
  }

  // ── Directory resolution ──────────────────────────────────────────────────

  static Future<Directory?> _recordingDir() async {
    try {
      // Prefer whatever RustDesk has configured via settings
      try {
        final configured =
            bind.mainGetOptionSync(key: 'video-save-directory').trim();
        if (configured.isNotEmpty) {
          final d = Directory(configured);
          if (d.existsSync()) return d;
        }
      } catch (_) {}

      // Fall back to platform default used by RustDesk's video_save_directory()
      if (Platform.isMacOS) {
        final lib = await getLibraryDirectory();
        return Directory(
            p.join(lib.path, 'Application Support', 'GuDesk', 'recording'));
      }
      if (Platform.isWindows) {
        final drive = Platform.environment['SystemDrive'] ?? 'C:';
        return Directory('$drive\\ProgramData\\GuDesk\\recording');
      }
      final support = await getApplicationSupportDirectory();
      return Directory(p.join(support.path, 'GuDesk', 'recording'));
    } catch (_) {
      return null;
    }
  }
}
