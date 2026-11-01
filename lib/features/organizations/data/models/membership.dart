import '../../../auth/data/models/staff_user.dart';
import 'organization.dart';

/// The signed-in person's place in one organization: which organization,
/// their role there, and whether that access is still active.
class Membership {
  const Membership({
    required this.organization,
    required this.role,
    required this.isActive,
    required this.userId,
    required this.fullName,
    required this.contact,
  });

  final Organization organization;
  final StaffRole role;
  final bool isActive;
  final String userId;
  final String fullName;

  /// Phone number for staff accounts, email for owners who signed up
  /// with one.
  final String contact;

  /// The person as the rest of the app sees them inside this organization.
  StaffUser toStaffUser() {
    return StaffUser(
      id: userId,
      fullName: fullName,
      role: role,
      phone: contact,
    );
  }

  /// Parses a `tenant_members` row with `tenants(*)` and
  /// `profiles!user_id(full_name, phone, email)` embedded.
  factory Membership.fromJson(Map<String, dynamic> json) {
    final profile = json['profiles'] as Map<String, dynamic>? ?? const {};
    return Membership(
      organization: Organization.fromJson(
        json['tenants'] as Map<String, dynamic>,
      ),
      role: staffRoleFromDb(json['role'] as String),
      isActive: json['is_active'] as bool,
      userId: json['user_id'] as String,
      fullName: profile['full_name'] as String? ?? 'Unknown',
      contact: profile['phone'] as String? ?? profile['email'] as String? ?? '',
    );
  }
}
