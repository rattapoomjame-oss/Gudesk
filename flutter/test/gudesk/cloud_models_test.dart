// Tests for GdCloudContact, GdCloudUser, GdCloudOrg, GdCloudSession, GdCloudTokens.
// Pure models — no FFI, no Flutter engine required.
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_hbb/gudesk/cloud/auth_model.dart';

void main() {
  // ── GdCloudOrg ─────────────────────────────────────────────────────────────

  group('GdCloudOrg.fromJson', () {
    test('parses all fields', () {
      final org = GdCloudOrg.fromJson({
        'id': 'org-1', 'name': 'Acme', 'slug': 'acme', 'plan': 'starter',
      });
      expect(org.id,   'org-1');
      expect(org.name, 'Acme');
      expect(org.slug, 'acme');
      expect(org.plan, 'starter');
    });

    test('defaults plan to trial when absent', () {
      final org = GdCloudOrg.fromJson({
        'id': 'x', 'name': 'X', 'slug': 'x',
      });
      expect(org.plan, 'trial');
    });
  });

  // ── GdCloudUser ───────────────────────────────────────────────────────────

  group('GdCloudUser.fromJson', () {
    test('parses camelCase orgId', () {
      final user = GdCloudUser.fromJson({
        'id': 'u1', 'orgId': 'o1', 'email': 'a@b.com', 'name': 'Alice', 'role': 'it_manager',
      });
      expect(user.orgId, 'o1');
    });

    test('falls back to snake_case org_id', () {
      final user = GdCloudUser.fromJson({
        'id': 'u1', 'org_id': 'o2', 'email': 'a@b.com', 'name': 'Alice', 'role': 'technician',
      });
      expect(user.orgId, 'o2');
    });

    test('isManager true for it_manager', () {
      final user = GdCloudUser.fromJson({
        'id': 'u1', 'orgId': 'o1', 'email': 'a@b.com', 'name': 'A', 'role': 'it_manager',
      });
      expect(user.isManager, isTrue);
    });

    test('isManager true for super_admin', () {
      final user = GdCloudUser.fromJson({
        'id': 'u1', 'orgId': 'o1', 'email': 'a@b.com', 'name': 'A', 'role': 'super_admin',
      });
      expect(user.isManager, isTrue);
    });

    test('isManager false for technician', () {
      final user = GdCloudUser.fromJson({
        'id': 'u1', 'orgId': 'o1', 'email': 'a@b.com', 'name': 'A', 'role': 'technician',
      });
      expect(user.isManager, isFalse);
    });
  });

  // ── GdCloudTokens ─────────────────────────────────────────────────────────

  group('GdCloudTokens.fromJson', () {
    test('parses all fields', () {
      final t = GdCloudTokens.fromJson({
        'accessToken': 'acc', 'refreshToken': 'ref', 'expiresIn': 900,
      });
      expect(t.accessToken,  'acc');
      expect(t.refreshToken, 'ref');
      expect(t.expiresIn,    900);
    });

    test('defaults expiresIn to 900 when absent', () {
      final t = GdCloudTokens.fromJson({
        'accessToken': 'a', 'refreshToken': 'r',
      });
      expect(t.expiresIn, 900);
    });
  });

  // ── GdCloudSession ────────────────────────────────────────────────────────

  group('GdCloudSession.fromJson', () {
    final baseJson = {
      'accessToken':  'tok-acc',
      'refreshToken': 'tok-ref',
      'expiresIn':    900,
      'user': {
        'id': 'u1', 'orgId': 'o1', 'email': 'a@b.com', 'name': 'Alice', 'role': 'it_manager',
      },
    };

    test('parses tokens and user', () {
      final s = GdCloudSession.fromJson(baseJson);
      expect(s.tokens.accessToken, 'tok-acc');
      expect(s.user.email,         'a@b.com');
    });

    test('org is null when not in response (login)', () {
      final s = GdCloudSession.fromJson(baseJson);
      expect(s.org, isNull);
    });

    test('org is parsed when present (register-org)', () {
      final s = GdCloudSession.fromJson({
        ...baseJson,
        'org': {'id': 'o1', 'name': 'Acme', 'slug': 'acme', 'plan': 'trial'},
      });
      expect(s.org?.name, 'Acme');
    });
  });

  // ── GdCloudContact ────────────────────────────────────────────────────────

  group('GdCloudContact.fromJson', () {
    final baseJson = {
      'id':          'c-uuid',
      'remote_id':   '123456',
      'alias':       'Client A',
      'password':    'secret',
      'group_name':  'VIP',
      'notes':       'Important client',
      'tags':        ['important', 'vip'],
      'color_label': '#FF0000',
      'is_favorite': true,
      'is_pinned':   false,
      'updated_at':  '2026-06-01T12:00:00.000Z',
    };

    test('parses all standard fields', () {
      final c = GdCloudContact.fromJson(baseJson);
      expect(c.cloudId,   'c-uuid');
      expect(c.remoteId,  '123456');
      expect(c.alias,     'Client A');
      expect(c.password,  'secret');
      expect(c.groupName, 'VIP');
      expect(c.notes,     'Important client');
      expect(c.colorLabel, '#FF0000');
      expect(c.isFavorite, isTrue);
      expect(c.isPinned,   isFalse);
    });

    test('parses tags list', () {
      final c = GdCloudContact.fromJson(baseJson);
      expect(c.tags, ['important', 'vip']);
    });

    test('empty tags list when absent', () {
      final j = Map<String, dynamic>.from(baseJson)..remove('tags');
      final c = GdCloudContact.fromJson(j);
      expect(c.tags, isEmpty);
    });

    test('defaults alias to empty when absent', () {
      final j = Map<String, dynamic>.from(baseJson)..remove('alias');
      final c = GdCloudContact.fromJson(j);
      expect(c.alias, '');
    });

    test('defaults password to empty when absent', () {
      final j = Map<String, dynamic>.from(baseJson)..remove('password');
      final c = GdCloudContact.fromJson(j);
      expect(c.password, '');
    });

    test('color_label is nullable', () {
      final j = Map<String, dynamic>.from(baseJson)..['color_label'] = null;
      final c = GdCloudContact.fromJson(j);
      expect(c.colorLabel, isNull);
    });

    test('parses updatedAt as DateTime', () {
      final c = GdCloudContact.fromJson(baseJson);
      expect(c.updatedAt, isA<DateTime>());
      expect(c.updatedAt.year, 2026);
    });
  });
}
