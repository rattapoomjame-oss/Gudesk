import 'package:flutter_hbb/gudesk/transfer/models.dart';
import 'package:flutter_test/flutter_test.dart';

GdJobSnapshot _makeJob({
  GdJobStatus status = GdJobStatus.inProgress,
  double speed = 0,
  int totalSize = 0,
  int finishedSize = 0,
}) =>
    GdJobSnapshot(
      status: status,
      speed: speed,
      totalSize: totalSize,
      finishedSize: finishedSize,
    );

void main() {
  // ── GdQueueSummary.compute ────────────────────────────────────────────────

  group('GdQueueSummary.compute', () {
    test('empty list gives zeroed summary', () {
      final s = GdQueueSummary.compute([]);
      expect(s.inProgress, 0);
      expect(s.waiting, 0);
      expect(s.done, 0);
      expect(s.errors, 0);
      expect(s.speedBps, 0);
      expect(s.hasActive, isFalse);
    });

    test('counts inProgress jobs correctly', () {
      final s = GdQueueSummary.compute([
        _makeJob(status: GdJobStatus.inProgress),
        _makeJob(status: GdJobStatus.inProgress),
      ]);
      expect(s.inProgress, 2);
      expect(s.waiting, 0);
    });

    test('paused and queued are counted as waiting', () {
      final s = GdQueueSummary.compute([
        _makeJob(status: GdJobStatus.paused),
        _makeJob(status: GdJobStatus.queued),
      ]);
      expect(s.waiting, 2);
      expect(s.inProgress, 0);
    });

    test('done and error are counted separately', () {
      final s = GdQueueSummary.compute([
        _makeJob(status: GdJobStatus.done),
        _makeJob(status: GdJobStatus.error),
      ]);
      expect(s.done, 1);
      expect(s.errors, 1);
      expect(s.hasActive, isFalse);
    });

    test('aggregates speed across inProgress jobs', () {
      final s = GdQueueSummary.compute([
        _makeJob(speed: 1024 * 1024),
        _makeJob(speed: 512 * 1024),
      ]);
      expect(s.speedBps, closeTo(1.5 * 1024 * 1024, 1));
    });

    test('aggregates totalBytes and finishedBytes only for inProgress', () {
      final s = GdQueueSummary.compute([
        _makeJob(
            status: GdJobStatus.inProgress,
            totalSize: 1000,
            finishedSize: 400),
        _makeJob(
            status: GdJobStatus.done, totalSize: 500, finishedSize: 500),
      ]);
      expect(s.totalBytes, 1000); // only the inProgress job
      expect(s.finishedBytes, 400);
    });

    test('hasActive is true when there are inProgress jobs', () {
      final s = GdQueueSummary.compute([
        _makeJob(status: GdJobStatus.inProgress),
      ]);
      expect(s.hasActive, isTrue);
    });

    test('hasActive is true when there are waiting jobs', () {
      final s = GdQueueSummary.compute([
        _makeJob(status: GdJobStatus.paused),
      ]);
      expect(s.hasActive, isTrue);
    });

    test('hasActive is false with only done/error jobs', () {
      final s = GdQueueSummary.compute([
        _makeJob(status: GdJobStatus.done),
        _makeJob(status: GdJobStatus.error),
      ]);
      expect(s.hasActive, isFalse);
    });
  });

  // ── GdQueueSummary.etaSeconds ─────────────────────────────────────────────

  group('GdQueueSummary.etaSeconds', () {
    test('null when speed is 0', () {
      const s = GdQueueSummary(
        inProgress: 1,
        waiting: 0,
        done: 0,
        errors: 0,
        speedBps: 0,
        totalBytes: 1000,
        finishedBytes: 0,
      );
      expect(s.etaSeconds, isNull);
    });

    test('null when already finished', () {
      const s = GdQueueSummary(
        inProgress: 1,
        waiting: 0,
        done: 0,
        errors: 0,
        speedBps: 1000,
        totalBytes: 1000,
        finishedBytes: 1000,
      );
      expect(s.etaSeconds, isNull);
    });

    test('computed correctly for simple case', () {
      const s = GdQueueSummary(
        inProgress: 1,
        waiting: 0,
        done: 0,
        errors: 0,
        speedBps: 1000,
        totalBytes: 5000,
        finishedBytes: 0,
      );
      expect(s.etaSeconds, 5);
    });

    test('computed correctly with partial progress', () {
      const s = GdQueueSummary(
        inProgress: 1,
        waiting: 0,
        done: 0,
        errors: 0,
        speedBps: 500,
        totalBytes: 5000,
        finishedBytes: 2500,
      );
      expect(s.etaSeconds, 5);
    });
  });

  // ── GdQueueSummary.displayEta ─────────────────────────────────────────────

  group('GdQueueSummary.displayEta', () {
    test('returns "--" when eta is null', () {
      const s = GdQueueSummary(
        inProgress: 0,
        waiting: 0,
        done: 0,
        errors: 0,
        speedBps: 0,
        totalBytes: 0,
        finishedBytes: 0,
      );
      expect(s.displayEta, '--');
    });

    test('formats seconds under a minute', () {
      const s = GdQueueSummary(
        inProgress: 1,
        waiting: 0,
        done: 0,
        errors: 0,
        speedBps: 1000,
        totalBytes: 30000,
        finishedBytes: 0,
      );
      expect(s.displayEta, '30s');
    });

    test('formats minutes and seconds for 1-59 minutes', () {
      const s = GdQueueSummary(
        inProgress: 1,
        waiting: 0,
        done: 0,
        errors: 0,
        speedBps: 1000,
        totalBytes: 150000,
        finishedBytes: 0,
      );
      // 150s = 2m 30s
      expect(s.displayEta, '2m 30s');
    });

    test('formats hours and minutes for >= 1 hour', () {
      const s = GdQueueSummary(
        inProgress: 1,
        waiting: 0,
        done: 0,
        errors: 0,
        speedBps: 1000,
        totalBytes: 7200000,
        finishedBytes: 0,
      );
      // 7200s = 2h 0m
      expect(s.displayEta, '2h 0m');
    });
  });

  // ── GdQueueSummary.displaySpeed ───────────────────────────────────────────

  group('GdQueueSummary.displaySpeed', () {
    test('returns "--" when speed is 0', () {
      const s = GdQueueSummary(
        inProgress: 0,
        waiting: 0,
        done: 0,
        errors: 0,
        speedBps: 0,
        totalBytes: 0,
        finishedBytes: 0,
      );
      expect(s.displaySpeed, '--');
    });

    test('formats KB/s for sub-MB speed', () {
      const s = GdQueueSummary(
        inProgress: 1,
        waiting: 0,
        done: 0,
        errors: 0,
        speedBps: 512 * 1024,
        totalBytes: 0,
        finishedBytes: 0,
      );
      expect(s.displaySpeed, contains('KB/s'));
    });

    test('formats MB/s for MB-range speed', () {
      const s = GdQueueSummary(
        inProgress: 1,
        waiting: 0,
        done: 0,
        errors: 0,
        speedBps: 10 * 1024 * 1024,
        totalBytes: 0,
        finishedBytes: 0,
      );
      expect(s.displaySpeed, contains('MB/s'));
    });
  });

  // ── GdPausedJob ───────────────────────────────────────────────────────────

  group('GdPausedJob', () {
    test('stores all fields correctly', () {
      const job = GdPausedJob(
        remote: '/remote/file.txt',
        to: '/local/dest/',
        isRemoteToLocal: true,
        fileNum: 5,
        showHidden: false,
        fileCount: 10,
        totalSize: 1024 * 1024,
        jobName: 'My Transfer',
      );
      expect(job.remote, '/remote/file.txt');
      expect(job.to, '/local/dest/');
      expect(job.isRemoteToLocal, isTrue);
      expect(job.fileNum, 5);
      expect(job.showHidden, isFalse);
      expect(job.fileCount, 10);
      expect(job.totalSize, 1024 * 1024);
      expect(job.jobName, 'My Transfer');
    });
  });
}
