import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/bank_details.dart';
import '../models/business_profile.dart';
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

  /// Sets (or, with null, clears) the bank details printed in SMS debt
  /// reminders. Owner/Admin only (enforced by RLS).
  Future<Organization> updateBankDetails({
    required String organizationId,
    required BankDetails? details,
  });

  /// Name and business profile (Owner/Admin, enforced by RLS).
  Future<Organization> updateProfile({
    required String organizationId,
    required String name,
    required BusinessProfile profile,
  });

  /// Uploads a logo (PNG/JPEG/WebP, under 5 MB) and links it.
  Future<Organization> uploadLogo({
    required String organizationId,
    required Uint8List bytes,
    required String extension,
  });

  Future<Organization> removeLogo(String organizationId);

  /// The logo's bytes, for showing it and putting it on PDFs.
  Future<Uint8List> downloadLogo(String path);

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
  static const _organizationColumns =
      'id, name, logo_path, bank_name, bank_account_number, bank_account_name, '
      'address, phone, email, rc_number, nafdac_number';
  static const _bucket = 'tenant-files';
  static const _selectMembership =
      'role, is_active, user_id, tenants($_organizationColumns), '
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
  Future<Organization> updateBankDetails({
    required String organizationId,
    required BankDetails? details,
  }) async {
    final row = await _client
        .from('tenants')
        .update(BankDetails.toTenantJson(details))
        .eq('id', organizationId)
        .select(_organizationColumns)
        .single();
    return Organization.fromJson(row);
  }

  @override
  Future<Organization> updateProfile({
    required String organizationId,
    required String name,
    required BusinessProfile profile,
  }) => _update(organizationId, {'name': name, ...profile.toTenantJson()});

  @override
  Future<Organization> uploadLogo({
    required String organizationId,
    required Uint8List bytes,
    required String extension,
  }) async {
    final type = extension == 'jpg' ? 'jpeg' : extension;
    final path =
        '$organizationId/logo-${DateTime.now().millisecondsSinceEpoch}.$extension';
    await _client.storage
        .from(_bucket)
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: 'image/$type'),
        );
    final previous = await _logoPath(organizationId);
    final updated = await _update(organizationId, {'logo_path': path});
    if (previous != null) {
      await _client.storage.from(_bucket).remove([previous]);
    }
    return updated;
  }

  @override
  Future<Organization> removeLogo(String organizationId) async {
    final previous = await _logoPath(organizationId);
    final updated = await _update(organizationId, {'logo_path': null});
    if (previous != null) {
      await _client.storage.from(_bucket).remove([previous]);
    }
    return updated;
  }

  @override
  Future<Uint8List> downloadLogo(String path) =>
      _client.storage.from(_bucket).download(path);

  Future<String?> _logoPath(String organizationId) async {
    final row = await _client
        .from('tenants')
        .select('logo_path')
        .eq('id', organizationId)
        .single();
    return row['logo_path'] as String?;
  }

  Future<Organization> _update(
    String organizationId,
    Map<String, dynamic> values,
  ) async {
    final row = await _client
        .from('tenants')
        .update(values)
        .eq('id', organizationId)
        .select(_organizationColumns)
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
