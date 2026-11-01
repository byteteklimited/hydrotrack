import '../../../auth/data/models/staff_user.dart';

/// Where an invite code stands.
enum InvitationStatus { pending, accepted, revoked, expired }

/// A single-use code an Owner/Admin gives someone so they can join the
/// organization with the role chosen here.
class Invitation {
  const Invitation({
    required this.id,
    required this.code,
    required this.fullName,
    required this.role,
    required this.createdAt,
    required this.expiresAt,
    this.phone,
    this.email,
    this.acceptedAt,
    this.revokedAt,
  });

  final String id;
  final String code;
  final String fullName;
  final StaffRole role;
  final String? phone;
  final String? email;
  final DateTime createdAt;
  final DateTime expiresAt;
  final DateTime? acceptedAt;
  final DateTime? revokedAt;

  /// Who the invite was sent to — phone for staff, email otherwise.
  String get sentTo => phone ?? email ?? '';

  InvitationStatus statusAt(DateTime now) {
    if (acceptedAt != null) return InvitationStatus.accepted;
    if (revokedAt != null) return InvitationStatus.revoked;
    if (expiresAt.isBefore(now)) return InvitationStatus.expired;
    return InvitationStatus.pending;
  }

  factory Invitation.fromJson(Map<String, dynamic> json) {
    DateTime? optionalDate(String key) {
      final value = json[key] as String?;
      return value == null ? null : DateTime.parse(value);
    }

    return Invitation(
      id: json['id'] as String,
      code: json['code'] as String,
      fullName: json['full_name'] as String,
      role: staffRoleFromDb(json['role'] as String),
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      expiresAt: DateTime.parse(json['expires_at'] as String),
      acceptedAt: optionalDate('accepted_at'),
      revokedAt: optionalDate('revoked_at'),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'code': code,
      'full_name': fullName,
      'role': staffRoleToDb(role),
      'phone': phone,
      'email': email,
      'created_at': createdAt.toIso8601String(),
      'expires_at': expiresAt.toIso8601String(),
      'accepted_at': acceptedAt?.toIso8601String(),
      'revoked_at': revokedAt?.toIso8601String(),
    };
  }
}
