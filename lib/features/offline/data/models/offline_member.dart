import '../../../auth/data/models/staff_user.dart';
import 'offline_credential.dart';

/// A member of the device's organization, as downloaded for offline
/// sign-in.
class OfflineMember {
  const OfflineMember({
    required this.userId,
    required this.role,
    required this.isActive,
    required this.fullName,
    this.phone,
    this.email,
    this.credential,
  });

  final String userId;
  final StaffRole role;
  final bool isActive;
  final String fullName;
  final String? phone;
  final String? email;

  /// Null until they've signed in online at least once since offline
  /// sign-in was introduced.
  final OfflineCredential? credential;

  /// True when [identifier] (as typed on the sign-in screen) is this
  /// person's phone number or email.
  bool isIdentifiedBy(String identifier) {
    final typed = normalizeIdentifier(identifier);
    if (typed.isEmpty) return false;
    return typed == normalizeIdentifier(phone ?? '') ||
        typed == normalizeIdentifier(email ?? '');
  }

  StaffUser toStaffUser() => StaffUser(
    id: userId,
    fullName: fullName,
    role: role,
    phone: phone ?? email ?? '',
  );

  /// Emails lower-cased; Nigerian phone numbers as 234XXXXXXXXXX whether
  /// typed as 080…, +234… or 234….
  static String normalizeIdentifier(String value) {
    final trimmed = value.trim();
    if (trimmed.contains('@')) return trimmed.toLowerCase();
    final digits = trimmed.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('0')) return '234${digits.substring(1)}';
    return digits;
  }

  factory OfflineMember.fromJson(Map<String, dynamic> json) {
    final credential = json['credential'] as Map<String, dynamic>?;
    return OfflineMember(
      userId: json['user_id'] as String,
      role: staffRoleFromDb(json['role'] as String),
      isActive: json['is_active'] as bool,
      fullName: json['full_name'] as String? ?? 'Unknown',
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      credential: credential == null
          ? null
          : OfflineCredential.fromJson(credential),
    );
  }

  Map<String, dynamic> toJson() => {
    'user_id': userId,
    'role': staffRoleToDb(role),
    'is_active': isActive,
    'full_name': fullName,
    'phone': phone,
    'email': email,
    'credential': credential?.toJson(),
  };
}
