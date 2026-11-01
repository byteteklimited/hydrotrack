import 'bank_details.dart';
import 'business_profile.dart';

/// One organization (tenant) — a water factory business using HydroTrack.
/// Every business record belongs to exactly one organization.
class Organization {
  const Organization({
    required this.id,
    required this.name,
    this.logoPath,
    this.bankDetails,
    this.profile = const BusinessProfile(),
  });

  final String id;
  final String name;

  /// Path inside the private `tenant-files` storage bucket, if a logo
  /// has been uploaded.
  final String? logoPath;

  /// Where customers pay; printed in SMS debt reminders. Null if not set.
  final BankDetails? bankDetails;

  /// Address, contacts and registration numbers for receipts and reports.
  final BusinessProfile profile;

  factory Organization.fromJson(Map<String, dynamic> json) {
    return Organization(
      id: json['id'] as String,
      name: json['name'] as String,
      logoPath: json['logo_path'] as String?,
      bankDetails: BankDetails.fromTenantJson(json),
      profile: BusinessProfile.fromTenantJson(json),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'logo_path': logoPath,
      ...BankDetails.toTenantJson(bankDetails),
      ...profile.toTenantJson(),
    };
  }
}
