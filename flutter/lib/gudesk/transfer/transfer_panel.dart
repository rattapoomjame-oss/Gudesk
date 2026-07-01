import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/consts.dart';
import 'package:flutter_hbb/models/file_model.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:percent_indicator/percent_indicator.dart';

import 'file_bridge.dart';
import 'models.dart';
import 'pause_manager.dart';

/// Drop-in replacement for the file manager's inline statusList() widget.
///
/// Adds:
///  - Summary header: N active / M queued / speed / ETA
///  - Bulk actions: Pause All, Resume All, Clear Done
///  - Per-job Pause button for in-progress transfers
///  - Queue position badge for waiting transfers
class GdTransferPanel extends StatelessWidget {
  final JobController jobController;

  const GdTransferPanel({super.key, required this.jobController});

  @override
  Widget build(BuildContext context) {
    return PreferredSize(
      preferredSize: const Size(200, double.infinity),
      child: Container(
        margin: const EdgeInsets.only(top: 16, bottom: 16, right: 16),
        padding: const EdgeInsets.all(8),
        child: Obx(() {
          final jobs = jobController.jobTable;
          if (jobs.isEmpty) return _emptyState(context);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SummaryHeader(jobs: jobs),
              const SizedBox(height: 6),
              _BulkActions(jobController: jobController),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  controller: ScrollController(),
                  itemCount: jobs.length,
                  itemBuilder: (ctx, i) => _JobCard(
                    job: jobs[i],
                    jobController: jobController,
                    queuePosition: _waitingPosition(jobs, i),
                  ),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  // Returns 1-based waiting-queue position for paused/none jobs, null otherwise.
  int? _waitingPosition(List<JobProgress> jobs, int index) {
    if (jobs[index].state != JobState.paused &&
        jobs[index].state != JobState.none) return null;
    int pos = 0;
    for (int i = 0; i <= index; i++) {
      if (jobs[i].state == JobState.paused || jobs[i].state == JobState.none) {
        pos++;
      }
    }
    return pos;
  }

  Widget _emptyState(BuildContext context) {
    return _GdCard(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SvgPicture.asset(
              'assets/transfer.svg',
              colorFilter: svgColor(Theme.of(context).tabBarTheme.labelColor),
              height: 40,
            ).paddingOnly(bottom: 10),
            Text(
              translate('No transfers in progress'),
              textAlign: TextAlign.center,
              textScaler: const TextScaler.linear(1.20),
              style: TextStyle(
                  color: Theme.of(context).tabBarTheme.labelColor),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Summary header ────────────────────────────────────────────────────────

class _SummaryHeader extends StatelessWidget {
  final List<JobProgress> jobs;
  const _SummaryHeader({required this.jobs});

  @override
  Widget build(BuildContext context) {
    final s = GdQueueSummary.compute(jobs.map((j) => j.toSnapshot()).toList());
    if (!s.hasActive) return const SizedBox.shrink();
    return _GdCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Wrap(
          spacing: 16,
          runSpacing: 4,
          children: [
            if (s.inProgress > 0)
              _Chip(Icons.sync, '${s.inProgress} active', Colors.blue),
            if (s.waiting > 0)
              _Chip(Icons.schedule, '${s.waiting} queued', Colors.orange),
            if (s.speedBps > 0)
              _Chip(Icons.speed, s.displaySpeed, Colors.green),
            if (s.etaSeconds != null)
              _Chip(Icons.timer_outlined, 'ETA ${s.displayEta}',
                  Theme.of(context).colorScheme.secondary),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _Chip(this.icon, this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
                fontSize: 11, color: color, fontWeight: FontWeight.w500)),
      ],
    );
  }
}

// ── Bulk actions ──────────────────────────────────────────────────────────

class _BulkActions extends StatelessWidget {
  final JobController jobController;
  const _BulkActions({required this.jobController});

  bool get _hasInProgress => jobController.jobTable
      .any((j) => j.state == JobState.inProgress);
  bool get _hasPaused =>
      jobController.jobTable.any((j) => j.state == JobState.paused);
  bool get _hasDone => jobController.jobTable
      .any((j) => j.state == JobState.done || j.state == JobState.error);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (_hasInProgress)
          _SmallButton(
            icon: Icons.pause_circle_outline,
            label: 'Pause All',
            onPressed: () =>
                GdPauseManager.instance.pauseAll(jobController),
          ),
        if (_hasPaused) ...[
          if (_hasInProgress) const SizedBox(width: 4),
          _SmallButton(
            icon: Icons.play_circle_outline,
            label: 'Resume All',
            onPressed: () =>
                GdPauseManager.instance.resumeAll(jobController),
          ),
        ],
        const Spacer(),
        if (_hasDone)
          _SmallButton(
            icon: Icons.cleaning_services,
            label: 'Clear done',
            onPressed: _clearDone,
          ),
      ],
    );
  }

  void _clearDone() {
    jobController.jobTable
        .removeWhere((j) => j.state == JobState.done || j.state == JobState.error);
  }
}

class _SmallButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  const _SmallButton(
      {required this.icon, required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14,
                color: Theme.of(context).tabBarTheme.labelColor),
            const SizedBox(width: 3),
            Text(label,
                style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).tabBarTheme.labelColor)),
          ],
        ),
      ),
    );
  }
}

// ── Job card ──────────────────────────────────────────────────────────────

class _JobCard extends StatelessWidget {
  final JobProgress job;
  final JobController jobController;
  final int? queuePosition;

  const _JobCard({
    required this.job,
    required this.jobController,
    this.queuePosition,
  });

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).tabBarTheme.labelColor;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: _GdCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _directionIcon(color),
                Expanded(child: _centerColumn(context)),
                _actionButtons(context),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _directionIcon(Color? color) {
    if (job.type == JobType.deleteDir || job.type == JobType.deleteFile) {
      return Icon(Icons.delete_outline, color: color)
          .marginSymmetric(horizontal: 10, vertical: 12);
    }
    if (queuePosition != null) {
      return Stack(
        alignment: Alignment.center,
        children: [
          Icon(Icons.schedule, color: color)
              .marginSymmetric(horizontal: 10, vertical: 12),
          Positioned(
            right: 6,
            bottom: 6,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                  color: Colors.orange, borderRadius: BorderRadius.circular(6)),
              child: Text(
                '$queuePosition',
                style:
                    const TextStyle(fontSize: 9, color: Colors.white),
              ),
            ),
          ),
        ],
      );
    }
    return Transform.rotate(
      angle: job.isRemoteToLocal ? pi : 0,
      child:
          Icon(Icons.arrow_forward_ios, color: color),
    ).marginSymmetric(horizontal: 10, vertical: 12);
  }

  Widget _centerColumn(BuildContext context) {
    final status = job.display();
    final speed = job.speed > 0
        ? '${readableFileSize(job.speed)}/s'
        : null;
    final statusLine = [
      if (status.isNotEmpty) status,
      if (speed != null) speed,
    ].join('  ·  ');

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Tooltip(
          waitDuration: const Duration(milliseconds: 500),
          message: job.jobName,
          child: Text(
            job.jobName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (statusLine.isNotEmpty)
          Tooltip(
            waitDuration: const Duration(milliseconds: 500),
            message: statusLine,
            child: Text(
              statusLine,
              style: TextStyle(fontSize: 12, color: MyTheme.darkGray),
              overflow: TextOverflow.ellipsis,
            ),
          ).marginOnly(top: 4),
        if (job.type == JobType.transfer &&
            job.state == JobState.inProgress)
          LinearPercentIndicator(
            animateFromLastPercent: true,
            center: Text(job.percentText),
            barRadius: const Radius.circular(15),
            percent: job.percent.clamp(0.0, 1.0),
            progressColor: MyTheme.accent,
            backgroundColor: Theme.of(context).hoverColor,
            lineHeight: kDesktopFileTransferRowHeight,
          ).paddingSymmetric(vertical: 6),
      ],
    );
  }

  Widget _actionButtons(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Pause button — in-progress jobs only (GuDesk addition)
        if (job.state == JobState.inProgress)
          _iconBtn(
            icon: Icons.pause,
            tooltip: 'Pause',
            onPressed: () =>
                GdPauseManager.instance.pauseJob(jobController, job),
          ),
        // Resume button — paused jobs
        if (job.state == JobState.paused)
          _iconBtn(
            icon: Icons.play_arrow,
            tooltip: translate('Resume'),
            onPressed: () => jobController.resumeJob(job.id),
            accent: true,
          ),
        // Cancel / remove button
        _iconBtn(
          icon: Icons.close,
          tooltip: translate('Delete'),
          onPressed: () {
            final idx =
                jobController.jobTable.indexWhere((j) => j.id == job.id);
            if (idx != -1) jobController.jobTable.removeAt(idx);
            jobController.cancelJob(job.id);
            GdPauseManager.instance.clearPausedRecord(job.id);
          },
        ),
      ],
    ).marginAll(8);
  }

  Widget _iconBtn({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
    bool accent = false,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(icon,
              size: 18,
              color: accent ? MyTheme.accent : MyTheme.darkGray),
        ),
      ),
    );
  }
}

// ── Shared card widget ────────────────────────────────────────────────────

class _GdCard extends StatelessWidget {
  final Widget child;
  const _GdCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: const BorderRadius.all(Radius.circular(15)),
      ),
      child: child,
    );
  }
}
