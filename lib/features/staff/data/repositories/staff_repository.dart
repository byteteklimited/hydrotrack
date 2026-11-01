import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../auth/data/models/staff_user.dart';
import '../../../organizations/data/models/invitation.dart';
import '../models/audit_entry.dart';
import '../models/staff_member.dart';

/// Contract for the current organization's team: the roster, invite
/// codes, and member management (Owner/Admin only — enforced
/// server-side).
abstract class StaffRepository {
  Future<List<StaffMember>> fetchStaff();
  Future<List<AuditEntry>> fetchAuditTrail();

  /// Issues a single-use invite code for [phone]. The person joins with
  /// it and chooses their own PIN.
  Future<Invitation> inviteStaff({
    required String fullName,
    required String phone,
    required StaffRole role,
  });

  /// Every invite code issued, newest first.
  Future<List<Invitation>> fetchInvitations();
  Future<void> revokeInvitation(String invitationId);

  Future<StaffMember> setActive({
    required String staffId,
    required bool isActive,
  });

  Future<StaffMember> updateRole({
    required String staffId,
    required StaffRole role,
  });

  /// Removes someone from this organization (their account and other
  /// organizations are untouched). Rejected server-side — with a
  /// readable reason — if they have recorded activity here; deactivate
  /// them instead in that case.
  Future<void> removeMember(String staffId);
}

/// Backed by `tenant_members`, `tenant_invitations` and the
/// `audit_trail` view, scoped to one organization. Every write goes
/// through an RPC (`create_invitation`, `update_member_role`,
/// `set_member_active`, `remove_member`, `revoke_invitation`) that
/// enforces the owner/last-owner rules; each membership change is logged
/// to the audit trail by a trigger.
class SupabaseStaffRepository implements StaffRepository {
  SupabaseStaffRepository(this._tenantId);

  /// Every query and write is scoped to this organization.
  final String _tenantId;

  SupabaseClient get _client => Supabase.instance.client;

  static const _selectMember =
      'user_id, role, is_active, joined_at, '
      'profiles!user_id(full_name, phone, email)';

  @override
  Future<List<StaffMember>> fetchStaff() async {
    final rows = await _client
        .from('tenant_members')
        .select(_selectMember)
        .eq('tenant_id', _tenantId);
    final staff = (rows as List)
        .map((row) => StaffMember.fromJson(row as Map<String, dynamic>))
        .toList();
    staff.sort(
      (a, b) => a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()),
    );
    return staff;
  }

  Future<StaffMember> _fetchMember(String staffId) async {
    final row = await _client
        .from('tenant_members')
        .select(_selectMember)
        .eq('tenant_id', _tenantId)
        .eq('user_id', staffId)
        .single();
    return StaffMember.fromJson(row);
  }

  @override
  Future<List<AuditEntry>> fetchAuditTrail() async {
    final rows = await _client
        .from('audit_trail')
        .select()
        .eq('tenant_id', _tenantId)
        .order('at', ascending: false)
        .limit(200);
    return (rows as List)
        .map((row) => AuditEntry.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<Invitation> inviteStaff({
    required String fullName,
    required String phone,
    required StaffRole role,
  }) async {
    final row = await _client.rpc(
      'create_invitation',
      params: {
        'p_tenant_id': _tenantId,
        'p_full_name': fullName,
        'p_phone': phone,
        'p_email': null,
        'p_role': staffRoleToDb(role),
      },
    );
    return Invitation.fromJson(row as Map<String, dynamic>);
  }

  @override
  Future<List<Invitation>> fetchInvitations() async {
    final rows = await _client
        .from('tenant_invitations')
        .select()
        .eq('tenant_id', _tenantId)
        .order('created_at', ascending: false);
    return (rows as List)
        .map((row) => Invitation.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<void> revokeInvitation(String invitationId) {
    return _client.rpc(
      'revoke_invitation',
      params: {'p_tenant_id': _tenantId, 'p_invitation_id': invitationId},
    );
  }

  @override
  Future<StaffMember> setActive({
    required String staffId,
    required bool isActive,
  }) async {
    await _client.rpc(
      'set_member_active',
      params: {
        'p_tenant_id': _tenantId,
        'p_user_id': staffId,
        'p_active': isActive,
      },
    );
    return _fetchMember(staffId);
  }

  @override
  Future<StaffMember> updateRole({
    required String staffId,
    required StaffRole role,
  }) async {
    await _client.rpc(
      'update_member_role',
      params: {
        'p_tenant_id': _tenantId,
        'p_user_id': staffId,
        'p_role': staffRoleToDb(role),
      },
    );
    return _fetchMember(staffId);
  }

  @override
  Future<void> removeMember(String staffId) {
    return _client.rpc(
      'remove_member',
      params: {'p_tenant_id': _tenantId, 'p_user_id': staffId},
    );
  }
}
