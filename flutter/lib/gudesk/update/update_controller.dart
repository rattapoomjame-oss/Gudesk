import 'dart:io';

import 'package:convert/convert.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_hbb/models/platform_model.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

import 'update_models.dart';

const _kDefaultManifestUrl = 'https://update.gudesk.app/manifest.json';
const _kServerUrlKey = 'gd-update-server-url';
const _kAutoCheckDelaySecs = 30;

class GdUpdateController extends GetxController {
  static GdUpdateController get to => Get.find(tag: 'gudesk_update');

  final state = GdUpdateState.idle.obs;
  final manifest = Rxn<GdUpdateManifest>();
  final downloadProgress = Rxn<GdDownloadProgress>();
  final errorMessage = ''.obs;

  String? _platformKey;
  String? _downloadedPath;

  @override
  void onInit() {
    super.onInit();
    Future.delayed(
      const Duration(seconds: _kAutoCheckDelaySecs),
      checkForUpdate,
    );
  }

  // ── Public API ────────────────────────────────────────────────────────────

  Future<void> checkForUpdate() async {
    if (state.value == GdUpdateState.downloading ||
        state.value == GdUpdateState.verifying) return;
    state.value = GdUpdateState.checking;
    errorMessage.value = '';
    try {
      final url = _manifestUrl();
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) {
        throw Exception('Server returned HTTP ${response.statusCode}');
      }
      final m = GdUpdateManifest.tryParse(response.body);
      if (m == null) throw Exception('Could not parse update manifest');

      final current = await _currentVersion();
      if (semverCompare(m.version, current) > 0) {
        _platformKey = await _detectPlatformKey();
        if (_platformKey != null && m.platforms.containsKey(_platformKey)) {
          manifest.value = m;
          state.value = GdUpdateState.available;
        } else {
          state.value = GdUpdateState.idle;
        }
      } else {
        state.value = GdUpdateState.idle;
      }
    } catch (e) {
      errorMessage.value = e.toString();
      state.value = GdUpdateState.error;
    }
  }

  Future<void> downloadUpdate() async {
    final m = manifest.value;
    final key = _platformKey;
    if (m == null || key == null) return;
    final asset = m.platforms[key]!;

    state.value = GdUpdateState.downloading;
    downloadProgress.value =
        GdDownloadProgress(bytesReceived: 0, totalBytes: asset.size);
    _downloadedPath = null;
    errorMessage.value = '';

    try {
      final dir = await getTemporaryDirectory();
      final ext = asset.url.toLowerCase().endsWith('.exe') ? '.exe' : '.dmg';
      final file = File('${dir.path}/GuDesk-update-${m.version}$ext');

      final client = http.Client();
      final request = http.Request('GET', Uri.parse(asset.url));
      final response = await client.send(request);
      final total = response.contentLength ?? asset.size;

      final sink = file.openWrite();
      int received = 0;
      await for (final chunk in response.stream) {
        sink.add(chunk);
        received += chunk.length;
        downloadProgress.value =
            GdDownloadProgress(bytesReceived: received, totalBytes: total);
      }
      await sink.flush();
      await sink.close();
      client.close();

      state.value = GdUpdateState.verifying;
      final ok = await _verifyChecksum(file, asset.sha256);
      if (!ok) {
        await file.delete();
        throw Exception('SHA-256 mismatch — download may be corrupted');
      }

      _downloadedPath = file.path;
      state.value = GdUpdateState.readyToInstall;
    } catch (e) {
      errorMessage.value = e.toString();
      state.value = GdUpdateState.error;
    }
  }

  Future<void> applyUpdate() async {
    final path = _downloadedPath;
    if (path == null || state.value != GdUpdateState.readyToInstall) return;
    try {
      if (Platform.isWindows) {
        // Run installer; the UAC prompt will appear in the installer itself
        await Process.run('cmd', ['/c', 'start', '', path]);
      } else if (Platform.isMacOS) {
        // Open .dmg — user drags .app to /Applications
        await Process.run('open', [path]);
      }
    } catch (e) {
      errorMessage.value = e.toString();
      state.value = GdUpdateState.error;
    }
  }

  void dismissUpdate() {
    manifest.value = null;
    downloadProgress.value = null;
    _downloadedPath = null;
    state.value = GdUpdateState.idle;
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _manifestUrl() {
    try {
      final saved = bind.getLocalFlutterOption(k: _kServerUrlKey);
      return saved.isNotEmpty ? saved : _kDefaultManifestUrl;
    } catch (_) {
      return _kDefaultManifestUrl;
    }
  }

  Future<String> _currentVersion() async {
    try {
      return (await PackageInfo.fromPlatform()).version;
    } catch (_) {
      return '0.0.0';
    }
  }

  Future<String?> _detectPlatformKey() async {
    if (Platform.isWindows) return 'windows-x86_64';
    if (Platform.isMacOS) {
      try {
        final r = await Process.run('uname', ['-m']);
        return r.stdout.toString().trim() == 'arm64'
            ? 'macos-aarch64'
            : 'macos-x86_64';
      } catch (_) {
        return 'macos-aarch64';
      }
    }
    return null;
  }

  Future<bool> _verifyChecksum(File file, String expectedHex) async {
    if (expectedHex.isEmpty) return true;
    final output = AccumulatorSink<Digest>();
    final input = sha256.startChunkedConversion(output);
    await for (final chunk in file.openRead()) {
      input.add(chunk);
    }
    input.close();
    return output.events.single.toString() == expectedHex.toLowerCase();
  }
}
