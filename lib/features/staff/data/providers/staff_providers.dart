import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/action_controller.dart';
import '../../../organizations/data/models/invitation.dart';
import '../../../organizations/data/providers/organization_providers.dart';
import '../models/audit_entry.dart';
import '../models/staff_member.dart';
import '../repositories/staff_repository.dart';

/// The active [StaffRepository] implementation, for the current
/// organization.
final staffRepositoryProvider = Provider<StaffRepository>(
  (ref) => SupabaseStaffRepository(ref.watch(currentTenantIdProvider)),
);

/// The current organization's roster.
final staffProvider = FutureProvider<List<StaffMember>>((ref) {
  return ref.watch(staffRepositoryProvider).fetchStaff();
});

/// Every invite code issued for the current organization, newest first.
final invitationsProvider = FutureProvider<List<Invitation>>((ref) {
  return ref.watch(staffRepositoryProvider).fetchInvitations();
});

/// "Who did what, and when" — most recent first.
final auditTrailProvider = FutureProvider<List<AuditEntry>>((ref) {
  return ref.watch(staffRepositoryProvider).fetchAuditTrail();
});

/// Drives "Invite staff", "Revoke", "Deactivate"/"Reactivate", "Change
/// role" and "Remove": loading while the write is in flight, error (with
/// the server's reason, when it gave one) if it fails — otherwise
/// refreshes the roster, invites and audit trail.
class StaffActionController extends ActionController {
  StaffActionController(this._ref);

  final Ref _ref;

  StaffRepository get _repository => _ref.read(staffRepositoryProvider);

  /// A PIN reset code for [staffId], or null when it couldn't be made.
  Future<({String code, DateTime expiresAt})?> createPinReset(String staffId) {
    return guard(() => _repository.createPinReset(staffId));
  }

  Future<Invitation?> inviteStaff({
    required String fullName,
    required String phone,
    required StaffRole role,
  }) {
    return guard(() async {
      final invitation = await _repository.inviteStaff(
        fullName: fullName,
        phone: phone,
        role: role,
      );
      _refresh();
      return invitation;
    });
  }

  Future<bool> revokeInvitation(String invitationId) async {
    final result = await guard(() async {
      await _repository.revokeInvitation(invitationId);
      _refresh();
      return true;
    });
    return result ?? false;
  }

  Future<StaffMember?> setActive({
    required String staffId,
    required bool isActive,
  }) {
    return guard(() async {
      final updated = await _repository.setActive(
        staffId: staffId,
        isActive: isActive,
      );
      _refresh();
      return updated;
    });
  }

  Future<StaffMember?> updateRole({
    required String staffId,
    required StaffRole role,
  }) {
    return guard(() async {
      final updated = await _repository.updateRole(
        staffId: staffId,
        role: role,
      );
      _refresh();
      return updated;
    });
  }

  Future<bool> removeMember(String staffId) async {
    final result = await guard(() async {
      await _repository.removeMember(staffId);
      _refresh();
      return true;
    });
    return result ?? false;
  }

  void _refresh() {
    _ref.invalidate(staffProvider);
    _ref.invalidate(invitationsProvider);
    _ref.invalidate(auditTrailProvider);
  }
}

final staffActionControllerProvider =
    StateNotifierProvider<StaffActionController, AsyncValue<void>>(
      (ref) => StaffActionController(ref),
    );
