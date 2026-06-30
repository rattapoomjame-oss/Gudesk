// Pure models — no flutter_hbb or platform imports, fully unit-testable.

import 'dart:convert';

// ── Manifest ──────────────────────────────────────────────────────────────

class GdUpdateManifest {
  final String version;
  final String releaseNotes;
  final String publishedAt;
  final Map<String, GdPlatformAsset> platforms;

  const GdUpdateManifest({
    required this.version,
    required this.releaseNotes,
    required this.publishedAt,
    required this.platforms,
  });

  factory GdUpdateManifest.fromJson(Map<String, dynamic> json) {
    final raw = json['platforms'] as Map<String, dynamic>? ?? {};
    return GdUpdateManifest(
      version: json['version'] as String? ?? '',
      releaseNotes: json['release_notes'] as String? ?? '',
      publishedAt: json['published_at'] as String? ?? '',
      platforms: {
        for (final e in raw.entries)
          e.key: GdPlatformAsset.fromJson(e.value as Map<String, dynamic>)
      },
    );
  }

  static GdUpdateManifest? tryParse(String body) {
    try {
      return GdUpdateManifest.fromJson(jsonDecode(body) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }
}

class GdPlatformAsset {
  final String url;
  final String sha256;
  final int size;

  const GdPlatformAsset({
    required this.url,
    required this.sha256,
    required this.size,
  });

  factory GdPlatformAsset.fromJson(Map<String, dynamic> json) =>
      GdPlatformAsset(
        url: json['url'] as String? ?? '',
        sha256: json['sha256'] as String? ?? '',
        size: (json['size'] as num?)?.toInt() ?? 0,
      );
}

// ── State ─────────────────────────────────────────────────────────────────

enum GdUpdateState {
  idle,
  checking,
  available,
  downloading,
  verifying,
  readyToInstall,
  error,
}

// ── Download progress ─────────────────────────────────────────────────────

class GdDownloadProgress {
  final int bytesReceived;
  final int totalBytes;

  const GdDownloadProgress({
    required this.bytesReceived,
    required this.totalBytes,
  });

  double get fraction =>
      totalBytes <= 0 ? 0 : (bytesReceived / totalBytes).clamp(0.0, 1.0);

  String get displayPercent => '${(fraction * 100).toStringAsFixed(0)}%';
  String get displayReceived => gdFormatBytes(bytesReceived);
  String get displayTotal => gdFormatBytes(totalBytes);
}

// ── Semver comparison ─────────────────────────────────────────────────────

/// Returns positive if [a] > [b], 0 if equal, negative if [a] < [b].
/// Compares major.minor.patch numerically; strips a leading 'v' if present.
int semverCompare(String a, String b) {
  final pa = _parseSemver(a);
  final pb = _parseSemver(b);
  for (int i = 0; i < 3; i++) {
    final diff = pa[i] - pb[i];
    if (diff != 0) return diff;
  }
  return 0;
}

List<int> _parseSemver(String v) {
  final clean = v.startsWith('v') ? v.substring(1) : v;
  final parts = clean.split('.');
  return [
    for (int i = 0; i < 3; i++)
      i < parts.length ? (int.tryParse(parts[i]) ?? 0) : 0,
  ];
}

// ── Pure helpers ──────────────────────────────────────────────────────────

String gdFormatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
}
