/// Pure models for GuDesk Cloud authentication — no FFI, no flutter_hbb imports.

class GdCloudOrg {
  final String id;
  final String name;
  final String slug;
  final String plan;

  const GdCloudOrg({
    required this.id,
    required this.name,
    required this.slug,
    required this.plan,
  });

  factory GdCloudOrg.fromJson(Map<String, dynamic> j) => GdCloudOrg(
        id:   j['id']   as String,
        name: j['name'] as String,
        slug: j['slug'] as String,
        plan: j['plan'] as String? ?? 'trial',
      );
}

class GdCloudUser {
  final String id;
  final String orgId;
  final String email;
  final String name;
  final String role;

  const GdCloudUser({
    required this.id,
    required this.orgId,
    required this.email,
    required this.name,
    required this.role,
  });

  bool get isManager => role == 'it_manager' || role == 'super_admin';

  factory GdCloudUser.fromJson(Map<String, dynamic> j) => GdCloudUser(
        id:    j['id']     as String,
        orgId: j['orgId']  as String? ?? j['org_id'] as String,
        email: j['email']  as String,
        name:  j['name']   as String,
        role:  j['role']   as String,
      );
}

class GdCloudTokens {
  final String accessToken;
  final String refreshToken;
  final int expiresIn;

  const GdCloudTokens({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresIn,
  });

  factory GdCloudTokens.fromJson(Map<String, dynamic> j) => GdCloudTokens(
        accessToken:  j['accessToken']  as String,
        refreshToken: j['refreshToken'] as String,
        expiresIn:    j['expiresIn']    as int? ?? 900,
      );
}

/// Returned by login and register-org endpoints.
class GdCloudSession {
  final GdCloudTokens tokens;
  final GdCloudUser   user;
  final GdCloudOrg?   org;

  const GdCloudSession({
    required this.tokens,
    required this.user,
    this.org,
  });

  factory GdCloudSession.fromJson(Map<String, dynamic> j) => GdCloudSession(
        tokens: GdCloudTokens.fromJson(j),
        user:   GdCloudUser.fromJson(j['user'] as Map<String, dynamic>),
        org:    j['org'] != null
            ? GdCloudOrg.fromJson(j['org'] as Map<String, dynamic>)
            : null,
      );
}

/// A single contact entry returned by the cloud directory API.
class GdCloudContact {
  final String  cloudId;
  final String  remoteId;
  final String  alias;
  final String  password;
  final String  groupName;
  final String  notes;
  final List<String> tags;
  final String? colorLabel;
  final bool    isFavorite;
  final bool    isPinned;
  final DateTime updatedAt;

  const GdCloudContact({
    required this.cloudId,
    required this.remoteId,
    required this.alias,
    required this.password,
    required this.groupName,
    required this.notes,
    required this.tags,
    this.colorLabel,
    required this.isFavorite,
    required this.isPinned,
    required this.updatedAt,
  });

  factory GdCloudContact.fromJson(Map<String, dynamic> j) {
    final rawTags = j['tags'];
    final List<String> tags = rawTags is List
        ? rawTags.cast<String>()
        : <String>[];

    return GdCloudContact(
      cloudId:    j['id']          as String,
      remoteId:   j['remote_id']   as String,
      alias:      j['alias']       as String? ?? '',
      password:   j['password']    as String? ?? '',
      groupName:  j['group_name']  as String? ?? '',
      notes:      j['notes']       as String? ?? '',
      tags:       tags,
      colorLabel: j['color_label'] as String?,
      isFavorite: j['is_favorite'] as bool? ?? false,
      isPinned:   j['is_pinned']   as bool? ?? false,
      updatedAt:  DateTime.parse(j['updated_at'] as String),
    );
  }
}
