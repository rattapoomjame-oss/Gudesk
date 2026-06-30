import '../directory/models.dart';

/// Human-readable relative time from an ISO8601 last_seen timestamp.
String formatLastSeen(String? isoTimestamp, GdDeviceStatus status) {
  if (status == GdDeviceStatus.online || status == GdDeviceStatus.connecting) {
    return 'Now';
  }
  if (isoTimestamp == null || isoTimestamp.isEmpty) return 'Unknown';
  try {
    final dt = DateTime.parse(isoTimestamp).toLocal();
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  } catch (_) {
    return 'Unknown';
  }
}

/// Short label for status badge / tooltip.
String statusLabel(GdDeviceStatus status) {
  switch (status) {
    case GdDeviceStatus.online:
      return 'Online';
    case GdDeviceStatus.offline:
      return 'Offline';
    case GdDeviceStatus.connecting:
      return 'Connecting…';
    case GdDeviceStatus.busy:
      return 'Busy';
    case GdDeviceStatus.unknown:
      return 'Unknown';
  }
}
