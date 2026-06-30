import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:percent_indicator/percent_indicator.dart';

import 'update_controller.dart';
import 'update_models.dart';

// ── Update badge for toolbar ──────────────────────────────────────────────

/// Toolbar icon that pulses when an update is available.
/// Shows nothing while idle/checking.
class GdUpdateBadge extends StatelessWidget {
  const GdUpdateBadge({super.key});

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<GdUpdateController>(tag: 'gudesk_update')) {
      return const SizedBox.shrink();
    }
    final ctrl = GdUpdateController.to;
    return Obx(() {
      final s = ctrl.state.value;
      if (s == GdUpdateState.idle || s == GdUpdateState.checking) {
        return const SizedBox.shrink();
      }
      final color = s == GdUpdateState.error ? Colors.red : Colors.orange;
      final tip = s == GdUpdateState.available
          ? 'Update available: ${ctrl.manifest.value?.version ?? ''}'
          : s == GdUpdateState.error
              ? 'Update error — tap to retry'
              : 'Update in progress…';
      return Tooltip(
        message: tip,
        child: IconButton(
          icon: Badge(
            backgroundColor: color,
            child: const Icon(Icons.system_update_alt, size: 20),
          ),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          onPressed: () => showGdUpdateDialog(context),
        ),
      );
    });
  }
}

// ── Update dialog ─────────────────────────────────────────────────────────

void showGdUpdateDialog(BuildContext context) {
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _GdUpdateDialog(),
  );
}

class _GdUpdateDialog extends StatelessWidget {
  const _GdUpdateDialog();

  @override
  Widget build(BuildContext context) {
    final ctrl = GdUpdateController.to;
    return Obx(() {
      final s = ctrl.state.value;
      return AlertDialog(
        title: _title(s),
        content: SizedBox(
          width: 400,
          child: _body(context, ctrl, s),
        ),
        actions: _actions(context, ctrl, s),
      );
    });
  }

  Widget _title(GdUpdateState s) {
    return switch (s) {
      GdUpdateState.available => const Text('Update available'),
      GdUpdateState.downloading => const Text('Downloading update…'),
      GdUpdateState.verifying => const Text('Verifying download…'),
      GdUpdateState.readyToInstall => const Text('Ready to install'),
      GdUpdateState.error => const Text('Update error'),
      _ => const Text('Update'),
    };
  }

  Widget _body(
      BuildContext context, GdUpdateController ctrl, GdUpdateState s) {
    switch (s) {
      case GdUpdateState.available:
        final m = ctrl.manifest.value!;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _versionRow(m),
            const SizedBox(height: 12),
            if (m.releaseNotes.isNotEmpty) ...[
              const Text('Release notes:',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Theme.of(context).hoverColor,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(m.releaseNotes,
                    style: const TextStyle(fontSize: 12)),
              ),
            ],
          ],
        );

      case GdUpdateState.downloading:
      case GdUpdateState.verifying:
        final prog = ctrl.downloadProgress.value;
        final label = s == GdUpdateState.verifying
            ? 'Verifying…'
            : prog != null
                ? '${prog.displayReceived} / ${prog.displayTotal} (${prog.displayPercent})'
                : 'Connecting…';
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LinearPercentIndicator(
              animateFromLastPercent: true,
              percent: prog?.fraction ?? 0,
              progressColor: Theme.of(context).colorScheme.primary,
              backgroundColor: Theme.of(context).hoverColor,
              lineHeight: 12,
              barRadius: const Radius.circular(6),
            ),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(fontSize: 12)),
          ],
        );

      case GdUpdateState.readyToInstall:
        return const Text(
          'The installer has been downloaded and verified.\n'
          'Click Install to launch it now.',
          style: TextStyle(fontSize: 13),
        );

      case GdUpdateState.error:
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Something went wrong:'),
            const SizedBox(height: 8),
            Text(
              ctrl.errorMessage.value,
              style: const TextStyle(fontSize: 11, color: Colors.red),
            ),
          ],
        );

      default:
        return const SizedBox.shrink();
    }
  }

  List<Widget> _actions(
      BuildContext context, GdUpdateController ctrl, GdUpdateState s) {
    switch (s) {
      case GdUpdateState.available:
        return [
          TextButton(
            onPressed: () {
              ctrl.dismissUpdate();
              Navigator.pop(context);
            },
            child: const Text('Skip'),
          ),
          FilledButton(
            onPressed: () => ctrl.downloadUpdate(),
            child: const Text('Download'),
          ),
        ];

      case GdUpdateState.downloading:
      case GdUpdateState.verifying:
        return [
          TextButton(
            onPressed: () {
              ctrl.dismissUpdate();
              Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),
        ];

      case GdUpdateState.readyToInstall:
        return [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Later'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              ctrl.applyUpdate();
            },
            child: const Text('Install'),
          ),
        ];

      case GdUpdateState.error:
        return [
          TextButton(
            onPressed: () {
              ctrl.dismissUpdate();
              Navigator.pop(context);
            },
            child: const Text('Dismiss'),
          ),
          TextButton(
            onPressed: () => ctrl.checkForUpdate(),
            child: const Text('Retry'),
          ),
        ];

      default:
        return [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ];
    }
  }

  Widget _versionRow(GdUpdateManifest m) {
    return Row(
      children: [
        const Icon(Icons.new_releases_outlined, size: 18, color: Colors.green),
        const SizedBox(width: 8),
        Text(
          'Version ${m.version}',
          style:
              const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        if (m.publishedAt.isNotEmpty) ...[
          const SizedBox(width: 8),
          Text(
            _friendlyDate(m.publishedAt),
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
        ],
      ],
    );
  }

  String _friendlyDate(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }
}
