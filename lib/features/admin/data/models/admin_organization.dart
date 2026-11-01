import '../../../subscriptions/data/models/subscription.dart';

/// One organization as the HydroTrack admin console sees it
/// (`admin_organizations`).
class AdminOrganization {
  const AdminOrganization({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.staffCount,
    this.businessPhone,
    this.ownerName,
    this.ownerPhone,
    this.ownerEmail,
    this.lastActivityAt,
    this.subscription,
  });

  final String id;
  final String name;
  final DateTime createdAt;
  final int staffCount;
  final String? businessPhone;
  final String? ownerName;
  final String? ownerPhone;
  final String? ownerEmail;

  /// Latest sale, production run or money movement.
  final DateTime? lastActivityAt;
  final Subscription? subscription;

  /// For search: name and owner contact.
  bool matches(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return [
      name,
      ownerName,
      ownerPhone,
      ownerEmail,
      businessPhone,
    ].any((value) => value?.toLowerCase().contains(q) ?? false);
  }

  factory AdminOrganization.fromJson(Map<String, dynamic> json) =>
      AdminOrganization(
        id: json['id'] as String,
        name: json['name'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
        staffCount: json['staff_count'] as int,
        businessPhone: json['business_phone'] as String?,
        ownerName: json['owner_name'] as String?,
        ownerPhone: json['owner_phone'] as String?,
        ownerEmail: json['owner_email'] as String?,
        lastActivityAt: json['last_activity_at'] == null
            ? null
            : DateTime.parse(json['last_activity_at'] as String),
        subscription: json['subscription'] == null
            ? null
            : Subscription.fromJson(
                Map<String, dynamic>.from(json['subscription'] as Map),
              ),
      );
}
