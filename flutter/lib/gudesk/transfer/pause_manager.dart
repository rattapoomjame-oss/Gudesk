import 'package:flutter_hbb/models/file_model.dart';
import 'package:flutter_hbb/models/platform_model.dart';

import 'models.dart';

/// Implements "pause" for in-progress transfers by cancelling the running job
/// and re-queueing it from the current file index without auto-starting.
///
/// RustDesk has no native pause FFI, so pause = cancel + sessionAddJob(fileNum).
class GdPauseManager {
  GdPauseManager._();
  static final instance = GdPauseManager._();

  // Maps new (paused) actId → saved state, so we know which are GuDesk-paused.
  final _paused = <int, GdPausedJob>{};

  bool isGdPaused(int jobId) => _paused.containsKey(jobId);

  /// Pause an in-progress transfer: cancel the running job, snapshot state,
  /// and re-queue as a new paused job that can be resumed via [jobController.resumeJob].
  Future<void> pauseJob(JobController ctrl, JobProgress job) async {
    if (job.state != JobState.inProgress) return;

    final saved = GdPausedJob(
      remote: job.remote,
      to: job.to,
      isRemoteToLocal: job.isRemoteToLocal,
      fileNum: job.fileNum,
      showHidden: job.showHidden,
      fileCount: job.fileCount,
      totalSize: job.totalSize,
      jobName: job.jobName,
    );

    // Remove the original job from the visible list before cancelling so the
    // UI doesn't briefly show "Cancelled".
    final idx = ctrl.jobTable.indexWhere((j) => j.id == job.id);
    if (idx != -1) ctrl.jobTable.removeAt(idx);

    // Stop Rust-side transfer.
    try {
      await bind.sessionCancelJob(sessionId: ctrl.sessionId, actId: job.id);
    } catch (_) {}

    // Allocate a new job ID for the paused-resume slot.
    final newId = JobController.jobID.next();

    // Register the paused job in Rust so sessionResumeJob can start it later.
    try {
      await bind.sessionAddJob(
        sessionId: ctrl.sessionId,
        isRemote: saved.isRemoteToLocal,
        includeHidden: saved.showHidden,
        actId: newId,
        path: saved.isRemoteToLocal ? saved.remote : saved.to,
        to: saved.isRemoteToLocal ? saved.to : saved.remote,
        fileNum: saved.fileNum,
      );
    } catch (_) {}

    // Add the new paused entry to the visible job table.
    final paused = JobProgress()
      ..type = JobType.transfer
      ..state = JobState.paused
      ..id = newId
      ..isRemoteToLocal = saved.isRemoteToLocal
      ..jobName = saved.jobName
      ..remote = saved.remote
      ..to = saved.to
      ..fileNum = saved.fileNum
      ..fileCount = saved.fileCount
      ..totalSize = saved.totalSize
      ..showHidden = saved.showHidden;
    ctrl.jobTable.add(paused);

    _paused[newId] = saved;
  }

  void clearPausedRecord(int jobId) => _paused.remove(jobId);

  /// Pause every currently in-progress job.
  Future<void> pauseAll(JobController ctrl) async {
    final active = ctrl.jobTable
        .where((j) => j.state == JobState.inProgress)
        .toList();
    for (final j in active) {
      await pauseJob(ctrl, j);
    }
  }

  /// Resume every paused job (both GuDesk-paused and naturally queued).
  void resumeAll(JobController ctrl) {
    final paused = ctrl.jobTable
        .where((j) => j.state == JobState.paused)
        .map((j) => j.id)
        .toList();
    for (final id in paused) {
      ctrl.resumeJob(id);
    }
  }
}
