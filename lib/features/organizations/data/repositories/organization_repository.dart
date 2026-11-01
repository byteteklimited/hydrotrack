import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/membership.dart';
import '../models/organization.dart';

/// Contract for the signed-in person's organizations: which ones they
/// belong to, creating and joining one, and organization settings.
abstract class OrganizationRepository {
  /// Every organization the signed-in person belongs to — including
  /// ones where their access was deactivated, so the app can say so.
  Future<List<Membership>> fetchMyMemberships();

  /// Creates an organization with the caller as its Owner. The server
  /// also sets up its starter finished-goods catalog.
  Future<Organization> createOrganization(String name);

  /// Joins an organization with an invite code addressed to the signed-in
  /// person's phone or email. Returns the organization's id.
  Future<String> joinWithCode(String code);

  /// Renames an organization. Owner/Admin only (enforced by RLS).
  Future<Organization> renameOrganization({
    required String organizationId,
    required String name,
  });

  /// The organization the person last worked in, if any — reopened
  /// automatically on their next sign-in, on any device.
  String? lastOrganizationId();
  Future<void> rememberLastOrganization(String organizationId);
}

/// Backed by `tenant_members`/`tenants` and the onboarding RPCs
/// (`create_tenant`, `accept_invitation`). Not tenant-scoped itself — it's
/// what decides the current tenant in the first place. The last-used
/// organization is kept in the person's own auth metadata: a preference
/// only, never an access grant (RLS checks membership on every query).
class SupabaseOrganizationRepository implements OrganizationRepository {
  SupabaseClient get _client => Supabase.instance.client;

  static const _lastOrganizationKey = 'last_tenant_id';
  static const _selectMembership =
      'role, is_active, user_id, tenants(id, name, logo_path), '
      'profiles!user_id(full_name, phone, email)';

  @override
  Future<List<Membership>> fetchMyMemberships() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return const [];
    final rows = await _client
        .from('tenant_members')
        .select(_selectMembership)
        .eq('user_id', userId);
    final memberships = (rows as List)
        .map((row) => Membership.fromJson(row as Map<String, dynamic>))
        .toList();
    memberships.sort(
      (a, b) => a.organization.name.toLowerCase().compareTo(
        b.organization.name.toLowerCase(),
      ),
    );
    return memberships;
  }

  @override
  Future<Organization> createOrganization(String name) async {
    final row = await _client.rpc('create_tenant', params: {'p_name': name});
    return Organization.fromJson(row as Map<String, dynamic>);
  }

  @override
  Future<String> joinWithCode(String code) async {
    final tenantId = await _client.rpc(
      'accept_invitation',
      params: {'p_code': code},
    );
    return tenantId as String;
  }

  @override
  Future<Organization> renameOrganization({
    required String organizationId,
    required String name,
  }) async {
    final row = await _client
        .from('tenants')
        .update({'name': name})
        .eq('id', organizationId)
        .select('id, name, logo_path')
        .single();
    return Organization.fromJson(row);
  }

  @override
  String? lastOrganizationId() {
    return _client.auth.currentUser?.userMetadata?[_lastOrganizationKey]
        as String?;
  }

  @override
  Future<void> rememberLastOrganization(String organizationId) async {
    if (lastOrganizationId() == organizationId) return;
    await _client.auth.updateUser(
      UserAttributes(data: {_lastOrganizationKey: organizationId}),
    );
  }
}
