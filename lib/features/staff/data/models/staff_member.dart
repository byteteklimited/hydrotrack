import '../../../auth/data/models/staff_user.dart';

export '../../../auth/data/models/staff_user.dart'
    show StaffRole, StaffRoleLabel, StaffRolePermissions;

/// One person in the current organization's roster — a superset of
/// [StaffUser] with the membership status and join date needed to manage
/// the team. Role and active status are per organization.
class StaffMember {
  const StaffMember({
    required this.id,
    required this.fullName,
    required this.role,
    required this.phone,
    required this.isActive,
    required this.joinedOn,
  });

  final String id;
  final String fullName;
  final StaffRole role;
  final String phone;
  final bool isActive;
  final DateTime joinedOn;

  StaffMember copyWith({StaffRole? role, bool? isActive}) {
    return StaffMember(
      id: id,
      fullName: fullName,
      role: role ?? this.role,
      phone: phone,
      isActive: isActive ?? this.isActive,
      joinedOn: joinedOn,
    );
  }

  /// Parses a `tenant_members` row with
  /// `profiles!user_id(full_name, phone, email)` embedded. [phone] falls
  /// back to the email for owners who signed up with one.
  factory StaffMember.fromJson(Map<String, dynamic> json) {
    final profile = json['profiles'] as Map<String, dynamic>? ?? const {};
    return StaffMember(
      id: json['user_id'] as String,
      fullName: profile['full_name'] as String? ?? 'Unknown',
      role: staffRoleFromDb(json['role'] as String),
      phone: profile['phone'] as String? ?? profile['email'] as String? ?? '',
      isActive: json['is_active'] as bool,
      joinedOn: DateTime.parse(json['joined_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': id,
      'role': staffRoleToDb(role),
      'is_active': isActive,
      'joined_at': joinedOn.toIso8601String(),
      'profiles': {'full_name': fullName, 'phone': phone},
    };
  }
}
