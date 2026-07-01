import 'dart:convert';
import 'package:http/http.dart' as http;

import 'auth_model.dart';

/// Lightweight exception carrying HTTP status code.
class GdApiError implements Exception {
  final int    statusCode;
  final String message;
  const GdApiError(this.statusCode, this.message);

  @override
  String toString() => 'GdApiError($statusCode): $message';
}

/// HTTP client for GuDesk Cloud REST API.
/// All methods throw [GdApiError] on non-2xx responses.
class GdCloudApi {
  final String baseUrl;
  final http.Client _client;

  GdCloudApi(this.baseUrl, {http.Client? client})
      : _client = client ?? http.Client();

  String get _v1 => '${_stripTrailingSlashes(baseUrl)}/api/v1';

  // ── Auth ──────────────────────────────────────────────────────────────────

  Future<GdCloudSession> login(String email, String password) async {
    final body = await _post('$_v1/auth/login', {
      'email':    email,
      'password': password,
    });
    return GdCloudSession.fromJson(body);
  }

  Future<GdCloudSession> registerOrg({
    required String orgName,
    required String orgSlug,
    required String email,
    required String password,
    required String name,
  }) async {
    final body = await _post('$_v1/auth/register-org', {
      'orgName':  orgName,
      'orgSlug':  orgSlug,
      'email':    email,
      'password': password,
      'name':     name,
    });
    return GdCloudSession.fromJson(body);
  }

  Future<GdCloudSession> refreshToken(String refreshToken) async {
    final body = await _post('$_v1/auth/refresh', {'refreshToken': refreshToken});
    // refresh endpoint doesn't return user/org, only tokens — build minimal session
    return GdCloudSession(
      tokens: GdCloudTokens.fromJson(body),
      user:   GdCloudUser(
        id: '', orgId: '', email: '', name: '', role: '',
      ),
    );
  }

  Future<void> logout(String accessToken) async {
    await _postAuth('$_v1/auth/logout', accessToken, {});
  }

  // ── Contacts (shared directory) ───────────────────────────────────────────

  /// Fetches all contacts for the org. Pass [since] for incremental sync.
  Future<({List<GdCloudContact> contacts, String syncedAt})> getContacts(
    String accessToken, {
    DateTime? since,
  }) async {
    final url = since != null
        ? '$_v1/contacts?since=${Uri.encodeComponent(since.toIso8601String())}'
        : '$_v1/contacts';
    final body = await _getAuth(url, accessToken);
    final list = (body['contacts'] as List)
        .map((e) => GdCloudContact.fromJson(e as Map<String, dynamic>))
        .toList();
    return (contacts: list, syncedAt: body['syncedAt'] as String);
  }

  /// Bulk-upserts a list of local contacts to the cloud.
  Future<int> bulkUpsert(
    String accessToken,
    List<Map<String, dynamic>> contacts,
  ) async {
    final body = await _postAuth(
      '$_v1/contacts/bulk-upsert',
      accessToken,
      {'contacts': contacts},
    );
    return body['upserted'] as int? ?? 0;
  }

  // ── Me ────────────────────────────────────────────────────────────────────

  Future<GdCloudUser> getMe(String accessToken) async {
    final body = await _getAuth('$_v1/auth/me', accessToken);
    return GdCloudUser.fromJson(body);
  }

  // ── Internals ─────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> _post(String url, Map<String, dynamic> data) async {
    final resp = await _client.post(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(data),
    );
    return _parseResponse(resp);
  }

  Future<Map<String, dynamic>> _getAuth(String url, String token) async {
    final resp = await _client.get(
      Uri.parse(url),
      headers: {'Authorization': 'Bearer $token'},
    );
    return _parseResponse(resp);
  }

  Future<Map<String, dynamic>> _postAuth(
    String url,
    String token,
    Map<String, dynamic> data,
  ) async {
    final resp = await _client.post(
      Uri.parse(url),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(data),
    );
    return _parseResponse(resp);
  }

  Map<String, dynamic> _parseResponse(http.Response resp) {
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      if (resp.body.isEmpty) return {};
      return jsonDecode(resp.body) as Map<String, dynamic>;
    }
    String message = 'Request failed';
    try {
      final j = jsonDecode(resp.body) as Map<String, dynamic>;
      message = (j['error'] as Map<String, dynamic>?)?['message'] as String? ?? message;
    } catch (_) {}
    throw GdApiError(resp.statusCode, message);
  }

  void dispose() => _client.close();
}

String _stripTrailingSlashes(String s) {
  while (s.isNotEmpty && s.endsWith('/')) {
    s = s.substring(0, s.length - 1);
  }
  return s;
}
