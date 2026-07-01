import 'dart:convert';

enum GdDeviceStatus { online, offline, connecting, busy, unknown }

extension GdDeviceStatusExt on GdDeviceStatus {
  String get label {
    switch (this) {
      case GdDeviceStatus.online:
        return 'ONLINE';
      case GdDeviceStatus.offline:
        return 'OFFLINE';
      case GdDeviceStatus.connecting:
        return 'CONNECTING';
      case GdDeviceStatus.busy:
        return 'BUSY';
      case GdDeviceStatus.unknown:
        return 'UNKNOWN';
    }
  }

  static GdDeviceStatus fromString(String s) {
    switch (s.toUpperCase()) {
      case 'ONLINE':
        return GdDeviceStatus.online;
      case 'OFFLINE':
        return GdDeviceStatus.offline;
      case 'CONNECTING':
        return GdDeviceStatus.connecting;
      case 'BUSY':
        return GdDeviceStatus.busy;
      default:
        return GdDeviceStatus.unknown;
    }
  }
}

class GdDirectory {
  final int? id;
  final String name;
  final int? parentId;
  final DateTime createdAt;
  final DateTime updatedAt;

  const GdDirectory({
    this.id,
    required this.name,
    this.parentId,
    required this.createdAt,
    required this.updatedAt,
  });

  GdDirectory copyWith({
    int? id,
    String? name,
    int? parentId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      GdDirectory(
        id: id ?? this.id,
        name: name ?? this.name,
        parentId: parentId ?? this.parentId,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'parent_id': parentId,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory GdDirectory.fromMap(Map<String, dynamic> m) => GdDirectory(
        id: m['id'] as int?,
        name: m['name'] as String,
        parentId: m['parent_id'] as int?,
        createdAt: DateTime.parse(m['created_at'] as String),
        updatedAt: DateTime.parse(m['updated_at'] as String),
      );
}

class GdDevice {
  final int? id;
  final String remoteId;
  final String? alias;
  final int? directoryId;
  final List<String> tags;
  final String? notes;
  final String? lastSeen;
  final GdDeviceStatus status;
  final String? platform;
  final String? version;
  final String? colorLabel;
  final bool isFavorite;
  final bool isPinned;
  // Phase 7: auto-populated from peer_info on connection
  final String hostname;
  final String osDetail;
  final String ipLast;
  // Phase 11: cloud sync fields
  final String  password;
  final String? cloudId;
  final String  groupName;
  final DateTime createdAt;
  final DateTime updatedAt;

  const GdDevice({
    this.id,
    required this.remoteId,
    this.alias,
    this.directoryId,
    this.tags = const [],
    this.notes,
    this.lastSeen,
    this.status = GdDeviceStatus.unknown,
    this.platform,
    this.version,
    this.colorLabel,
    this.isFavorite = false,
    this.isPinned = false,
    this.hostname = '',
    this.osDetail = '',
    this.ipLast = '',
    this.password = '',
    this.cloudId,
    this.groupName = '',
    required this.createdAt,
    required this.updatedAt,
  });

  String get displayName => (alias != null && alias!.isNotEmpty) ? alias! : remoteId;

  GdDevice copyWith({
    int? id,
    String? remoteId,
    Object? alias = _sentinel,
    Object? directoryId = _sentinel,
    List<String>? tags,
    Object? notes = _sentinel,
    Object? lastSeen = _sentinel,
    GdDeviceStatus? status,
    Object? platform = _sentinel,
    Object? version = _sentinel,
    Object? colorLabel = _sentinel,
    bool? isFavorite,
    bool? isPinned,
    String? hostname,
    String? osDetail,
    String? ipLast,
    String? password,
    Object? cloudId = _sentinel,
    String? groupName,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      GdDevice(
        id: id ?? this.id,
        remoteId: remoteId ?? this.remoteId,
        alias: alias == _sentinel ? this.alias : alias as String?,
        directoryId: directoryId == _sentinel ? this.directoryId : directoryId as int?,
        tags: tags ?? this.tags,
        notes: notes == _sentinel ? this.notes : notes as String?,
        lastSeen: lastSeen == _sentinel ? this.lastSeen : lastSeen as String?,
        status: status ?? this.status,
        platform: platform == _sentinel ? this.platform : platform as String?,
        version: version == _sentinel ? this.version : version as String?,
        colorLabel: colorLabel == _sentinel ? this.colorLabel : colorLabel as String?,
        isFavorite: isFavorite ?? this.isFavorite,
        isPinned: isPinned ?? this.isPinned,
        hostname: hostname ?? this.hostname,
        osDetail: osDetail ?? this.osDetail,
        ipLast: ipLast ?? this.ipLast,
        password: password ?? this.password,
        cloudId: cloudId == _sentinel ? this.cloudId : cloudId as String?,
        groupName: groupName ?? this.groupName,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'remote_id':    remoteId,
        'alias':        alias,
        'directory_id': directoryId,
        'tags':         jsonEncode(tags),
        'notes':        notes,
        'last_seen':    lastSeen,
        'status':       status.label,
        'platform':     platform,
        'version':      version,
        'color_label':  colorLabel,
        'is_favorite':  isFavorite ? 1 : 0,
        'is_pinned':    isPinned ? 1 : 0,
        'hostname':     hostname,
        'os_detail':    osDetail,
        'ip_last':      ipLast,
        'password':     password,
        'cloud_id':     cloudId,
        'group_name':   groupName,
        'created_at':   createdAt.toIso8601String(),
        'updated_at':   updatedAt.toIso8601String(),
      };

  factory GdDevice.fromMap(Map<String, dynamic> m) {
    List<String> tags = [];
    try {
      final raw = m['tags'] as String?;
      if (raw != null && raw.isNotEmpty) {
        tags = List<String>.from(jsonDecode(raw));
      }
    } catch (_) {}
    return GdDevice(
      id: m['id'] as int?,
      remoteId: m['remote_id'] as String,
      alias: m['alias'] as String?,
      directoryId: m['directory_id'] as int?,
      tags: tags,
      notes: m['notes'] as String?,
      lastSeen: m['last_seen'] as String?,
      status: GdDeviceStatusExt.fromString(m['status'] as String? ?? ''),
      platform: m['platform'] as String?,
      version: m['version'] as String?,
      colorLabel: m['color_label'] as String?,
      isFavorite: (m['is_favorite'] as int? ?? 0) == 1,
      isPinned:   (m['is_pinned']   as int? ?? 0) == 1,
      hostname:   m['hostname']   as String? ?? '',
      osDetail:   m['os_detail']  as String? ?? '',
      ipLast:     m['ip_last']    as String? ?? '',
      password:   m['password']   as String? ?? '',
      cloudId:    m['cloud_id']   as String?,
      groupName:  m['group_name'] as String? ?? '',
      createdAt: DateTime.parse(m['created_at'] as String),
      updatedAt: DateTime.parse(m['updated_at'] as String),
    );
  }
}

// Sentinel for copyWith nullable field distinction
const _sentinel = Object();
