// Pure models — no flutter_hbb imports, so this file is unit-testable
// without generated_bridge.dart.

// ── GdJobStatus / GdJobSnapshot ───────────────────────────────────────────

enum GdJobStatus { inProgress, paused, queued, done, error }

/// Minimal, testable snapshot of a JobProgress entry used by GdQueueSummary.
class GdJobSnapshot {
  final GdJobStatus status;
  final double speed;
  final int totalSize;
  final int finishedSize;

  const GdJobSnapshot({
    required this.status,
    this.speed = 0,
    this.totalSize = 0,
    this.finishedSize = 0,
  });
}

// ── GdPausedJob ───────────────────────────────────────────────────────────

/// Snapshot of in-progress transfer state saved before a GuDesk-level pause.
class GdPausedJob {
  final String remote;
  final String to;
  final bool isRemoteToLocal;
  final int fileNum;
  final bool showHidden;
  final int fileCount;
  final int totalSize;
  final String jobName;

  const GdPausedJob({
    required this.remote,
    required this.to,
    required this.isRemoteToLocal,
    required this.fileNum,
    required this.showHidden,
    required this.fileCount,
    required this.totalSize,
    required this.jobName,
  });
}

// ── GdQueueSummary ────────────────────────────────────────────────────────

/// Aggregated stats across the entire job table for the summary header.
class GdQueueSummary {
  final int inProgress;
  final int waiting;
  final int done;
  final int errors;
  final double speedBps;
  final int totalBytes;
  final int finishedBytes;

  const GdQueueSummary({
    required this.inProgress,
    required this.waiting,
    required this.done,
    required this.errors,
    required this.speedBps,
    required this.totalBytes,
    required this.finishedBytes,
  });

  static GdQueueSummary compute(List<GdJobSnapshot> snapshots) {
    int ip = 0, waiting = 0, done = 0, errors = 0;
    double spd = 0;
    int total = 0, finished = 0;
    for (final j in snapshots) {
      switch (j.status) {
        case GdJobStatus.inProgress:
          ip++;
          spd += j.speed;
          total += j.totalSize;
          finished += j.finishedSize;
        case GdJobStatus.paused:
        case GdJobStatus.queued:
          waiting++;
        case GdJobStatus.done:
          done++;
        case GdJobStatus.error:
          errors++;
      }
    }
    return GdQueueSummary(
      inProgress: ip,
      waiting: waiting,
      done: done,
      errors: errors,
      speedBps: spd,
      totalBytes: total,
      finishedBytes: finished,
    );
  }

  bool get hasActive => inProgress > 0 || waiting > 0;

  int? get etaSeconds {
    final remaining = totalBytes - finishedBytes;
    if (speedBps <= 0 || remaining <= 0) return null;
    return (remaining / speedBps).ceil();
  }

  String get displaySpeed {
    if (speedBps <= 0) return '--';
    return '${_formatBytes(speedBps)}/s';
  }

  String get displayEta {
    final eta = etaSeconds;
    if (eta == null) return '--';
    if (eta < 60) return '${eta}s';
    if (eta < 3600) return '${eta ~/ 60}m ${eta % 60}s';
    return '${eta ~/ 3600}h ${(eta % 3600) ~/ 60}m';
  }
}

// ── Pure helpers ──────────────────────────────────────────────────────────

String _formatBytes(double bytes) {
  if (bytes < 1024) return '${bytes.toStringAsFixed(0)} B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
}
