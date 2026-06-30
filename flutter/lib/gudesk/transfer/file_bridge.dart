import 'package:flutter_hbb/models/file_model.dart';

import 'models.dart';

/// Drag payload for within-app panel-to-panel file transfers.
class GdTransferPayload {
  final SelectedItems items;
  final FileController sourceController;

  GdTransferPayload({required this.items, required this.sourceController});
}

/// Convert a [JobProgress] to a [GdJobSnapshot] for use with [GdQueueSummary].
extension JobProgressSnapshot on JobProgress {
  GdJobSnapshot toSnapshot() {
    final GdJobStatus status;
    switch (state) {
      case JobState.inProgress:
        status = GdJobStatus.inProgress;
      case JobState.paused:
        status = GdJobStatus.paused;
      case JobState.none:
        status = GdJobStatus.queued;
      case JobState.done:
        status = GdJobStatus.done;
      case JobState.error:
        status = GdJobStatus.error;
    }
    return GdJobSnapshot(
      status: status,
      speed: speed,
      totalSize: totalSize,
      finishedSize: finishedSize,
    );
  }
}
