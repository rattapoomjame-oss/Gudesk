import 'package:flutter_hbb/models/platform_model.dart';
import 'package:get/get.dart';

import '../directory/db.dart';
import '../directory/models.dart';
import 'auth_model.dart';
import 'cloud_api.dart';

// Persistent key names — stored via bind.getLocalFlutterOption
const _kCloudUrl          = 'gd-cloud-url';
const _kAccessToken       = 'gd-cloud-access-token';
const _kRefreshToken      = 'gd-cloud-refresh-token';
const _kUserId            = 'gd-cloud-user-id';
const _kUserEmail         = 'gd-cloud-user-email';
const _kUserName          = 'gd-cloud-user-name';
const _kUserRole          = 'gd-cloud-user-role';
const _kOrgId             = 'gd-cloud-org-id';
const _kOrgName           = 'gd-cloud-org-name';
const _kLastSync          = 'gd-cloud-last-sync';

class GdCloudController extends GetxController {
  static const tag = 'gudesk_cloud';

  // ── Observable state ──────────────────────────────────────────────────────

  final isLoggedIn    = false.obs;
  final isSyncing     = false.obs;
  final syncError     = Rxn<String>();
  final lastSyncedAt  = Rxn<DateTime>();
  final currentUser   = Rxn<GdCloudUser>();
  final currentOrg    = Rxn<GdCloudOrg>();
  // Org-level "Elevated Access Mode" — toggled by an admin on the web
  // dashboard, never from this app. When true (and the current user is
  // it_manager/super_admin), the directory auto-fills each org-enrolled
  // device's stored password on connect instead of asking for it.
  final elevatedAccessEnabled = false.obs;

  GdCloudApi? _api;

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void onInit() {
    super.onInit();
    _restoreSession();
  }

  @override
  void onClose() {
    _api?.dispose();
    super.onClose();
  }

  // ── Session persistence ───────────────────────────────────────────────────

  void _restoreSession() {
    final url   = bind.getLocalFlutterOption(k: _kCloudUrl);
    final token = bind.getLocalFlutterOption(k: _kAccessToken);
    if (url.isEmpty || token.isEmpty) return;

    _api = GdCloudApi(url);

    final user = GdCloudUser(
      id:    bind.getLocalFlutterOption(k: _kUserId),
      orgId: bind.getLocalFlutterOption(k: _kOrgId),
      email: bind.getLocalFlutterOption(k: _kUserEmail),
      name:  bind.getLocalFlutterOption(k: _kUserName),
      role:  bind.getLocalFlutterOption(k: _kUserRole),
    );
    if (user.id.isEmpty) return;

    final orgName = bind.getLocalFlutterOption(k: _kOrgName);
    currentUser.value = user;
    currentOrg.value  = GdCloudOrg(
      id: user.orgId, name: orgName, slug: '', plan: '',
    );
    isLoggedIn.value = true;

    final lastSync = bind.getLocalFlutterOption(k: _kLastSync);
    if (lastSync.isNotEmpty) {
      lastSyncedAt.value = DateTime.tryParse(lastSync);
    }

    // Best-effort, non-blocking — restoring a session shouldn't wait on this.
    _refreshElevatedAccess();
  }

  /// Refreshes [elevatedAccessEnabled] from the org row. Best-effort: on
  /// failure, leaves the last-known value in place rather than assuming off,
  /// since a transient network error shouldn't silently disable a policy
  /// the admin explicitly turned on.
  Future<void> _refreshElevatedAccess() async {
    if (_api == null) return;
    final user = currentUser.value;
    if (user == null || user.orgId.isEmpty) return;
    try {
      final token = bind.getLocalFlutterOption(k: _kAccessToken);
      final org = await _api!.getOrg(token, user.orgId);
      elevatedAccessEnabled.value = org['elevated_access_enabled'] == true;
    } catch (_) {}
  }

  /// Best-effort audit log of a connection made using an elevated-access
  /// auto-filled password. Never throws — must not block a connection.
  Future<void> logConnectionUse(String contactId) async {
    if (_api == null) return;
    try {
      final token = bind.getLocalFlutterOption(k: _kAccessToken);
      await _api!.logConnectionUse(token, contactId);
    } catch (_) {}
  }

  /// Saves a device's password back to its Cloud contact record so it's
  /// remembered org-wide. Returns true on success (unlike the audit log
  /// above, failures here are surfaced — the user explicitly asked to
  /// remember it, so silently dropping that would be misleading).
  Future<bool> updateContactPassword(String contactId, String password) async {
    if (_api == null) return false;
    try {
      final token = bind.getLocalFlutterOption(k: _kAccessToken);
      await _api!.updateContactPassword(token, contactId, password);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _persistSession(GdCloudSession session, String cloudUrl) async {
    await Future.wait([
      bind.setLocalFlutterOption(k: _kCloudUrl,      v: cloudUrl),
      bind.setLocalFlutterOption(k: _kAccessToken,   v: session.tokens.accessToken),
      bind.setLocalFlutterOption(k: _kRefreshToken,  v: session.tokens.refreshToken),
      bind.setLocalFlutterOption(k: _kUserId,        v: session.user.id),
      bind.setLocalFlutterOption(k: _kUserEmail,     v: session.user.email),
      bind.setLocalFlutterOption(k: _kUserName,      v: session.user.name),
      bind.setLocalFlutterOption(k: _kUserRole,      v: session.user.role),
      bind.setLocalFlutterOption(k: _kOrgId,         v: session.user.orgId),
      bind.setLocalFlutterOption(k: _kOrgName,       v: session.org?.name ?? ''),
    ]);
  }

  Future<void> _clearSession() async {
    for (final k in [
      _kAccessToken, _kRefreshToken, _kUserId, _kUserEmail,
      _kUserName, _kUserRole, _kOrgId, _kOrgName, _kLastSync,
    ]) {
      await bind.setLocalFlutterOption(k: k, v: '');
    }
  }

  // ── Auth actions ──────────────────────────────────────────────────────────

  /// Login with email + password. Returns null on success, error message on failure.
  Future<String?> login(String cloudUrl, String email, String password) async {
    try {
      _api?.dispose();
      _api = GdCloudApi(cloudUrl);
      final session = await _api!.login(email, password);
      await _persistSession(session, cloudUrl);

      currentUser.value  = session.user;
      currentOrg.value   = session.org;
      isLoggedIn.value   = true;
      syncError.value    = null;

      // Sync directory immediately after login
      await syncDirectory();
      await _refreshElevatedAccess();
      return null;
    } on GdApiError catch (e) {
      return e.message;
    } catch (e) {
      return 'Connection failed: $e';
    }
  }

  /// Register a new org + founder account.
  Future<String?> registerOrg({
    required String cloudUrl,
    required String orgName,
    required String orgSlug,
    required String email,
    required String password,
    required String name,
  }) async {
    try {
      _api?.dispose();
      _api = GdCloudApi(cloudUrl);
      final session = await _api!.registerOrg(
        orgName: orgName, orgSlug: orgSlug,
        email: email, password: password, name: name,
      );
      await _persistSession(session, cloudUrl);

      currentUser.value  = session.user;
      currentOrg.value   = session.org;
      isLoggedIn.value   = true;
      syncError.value    = null;
      return null;
    } on GdApiError catch (e) {
      return e.message;
    } catch (e) {
      return 'Connection failed: $e';
    }
  }

  Future<void> logout() async {
    try {
      final token = bind.getLocalFlutterOption(k: _kAccessToken);
      if (_api != null && token.isNotEmpty) {
        await _api!.logout(token).timeout(const Duration(seconds: 5));
      }
    } catch (_) {}

    _api?.dispose();
    _api = null;

    currentUser.value  = null;
    currentOrg.value   = null;
    isLoggedIn.value   = false;
    lastSyncedAt.value = null;
    syncError.value    = null;
    elevatedAccessEnabled.value = false;

    await _clearSession();
  }

  // ── Directory sync ────────────────────────────────────────────────────────

  /// Fetches contacts from the cloud and upserts into local SQLite.
  /// Uses incremental sync (since= lastSyncedAt) when available.
  Future<void> syncDirectory() async {
    if (_api == null || !isLoggedIn.value) return;

    isSyncing.value = true;
    syncError.value = null;

    try {
      String token = bind.getLocalFlutterOption(k: _kAccessToken);

      // Attempt token refresh if it looks expired (simple heuristic — just try)
      final (:contacts, :syncedAt) = await _api!.getContacts(
        token,
        since: lastSyncedAt.value,
      );

      await _upsertContactsLocally(contacts);

      final synced = DateTime.parse(syncedAt);
      lastSyncedAt.value = synced;
      await bind.setLocalFlutterOption(
        k: _kLastSync, v: syncedAt,
      );
      await _refreshElevatedAccess();
    } on GdApiError catch (e) {
      syncError.value = e.message;
    } catch (e) {
      syncError.value = 'Sync failed: $e';
    } finally {
      isSyncing.value = false;
    }
  }

  /// Converts cloud contacts → local GdDevice rows and upserts them.
  Future<void> _upsertContactsLocally(List<GdCloudContact> contacts) async {
    if (contacts.isEmpty) return;

    final db  = await GdDb.instance;
    final now = DateTime.now();

    for (final c in contacts) {
      // Resolve / create the local directory folder by group_name
      int? directoryId;
      if (c.groupName.isNotEmpty) {
        directoryId = await _resolveOrCreateDirectory(db, c.groupName, now);
      }

      final device = GdDevice(
        remoteId:    c.remoteId,
        alias:       c.alias.isEmpty ? null : c.alias,
        directoryId: directoryId,
        tags:        c.tags,
        notes:       c.notes.isEmpty ? null : c.notes,
        colorLabel:  c.colorLabel,
        isFavorite:  c.isFavorite,
        isPinned:    c.isPinned,
        password:    c.password,
        cloudId:     c.cloudId,
        groupName:   c.groupName,
        createdAt:   now,
        updatedAt:   c.updatedAt,
      );

      // Upsert by remote_id (ConflictAlgorithm.replace in GdDb.insertDevice)
      await GdDb.insertDevice(device);
    }
  }

  Future<int?> _resolveOrCreateDirectory(
    dynamic db,
    String name,
    DateTime now,
  ) async {
    final rows = await (db as dynamic).query(
      'directories',
      where: 'name = ?',
      whereArgs: [name],
      limit: 1,
    );
    if (rows.isNotEmpty) return rows.first['id'] as int?;

    final nowStr = now.toIso8601String();
    return db.insert('directories', {
      'name':       name,
      'created_at': nowStr,
      'updated_at': nowStr,
    });
  }
}
