import '../../../../core/theme/brand_palette.dart';
import 'bank_details.dart';
import 'business_profile.dart';
import 'water_limits.dart';

/// One organization (tenant) — a water factory business using HydroTrack.
/// Every business record belongs to exactly one organization.
class Organization {
  const Organization({
    required this.id,
    required this.name,
    this.logoPath,
    this.bankDetails,
    this.profile = const BusinessProfile(),
    this.waterLimits = const WaterLimits(),
    this.brandPrimary,
    this.brandAccent,
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

  /// What a water test must read to pass.
  final WaterLimits waterLimits;

  /// The organization's own colors, `#RRGGBB`; null = HydroTrack's.
  final String? brandPrimary;
  final String? brandAccent;

  /// The app's colors inside this organization.
  BrandPalette get palette => BrandPalette(
    primary:
        BrandPalette.parseHex(brandPrimary) ?? BrandPalette.hydrotrack.primary,
    accent:
        BrandPalette.parseHex(brandAccent) ?? BrandPalette.hydrotrack.accent,
  );

  /// Two letters for a badge when there's no logo, e.g. "SW".
  String get initials {
    final words = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    return words.take(2).map((w) => w[0].toUpperCase()).join();
  }

  factory Organization.fromJson(Map<String, dynamic> json) {
    return Organization(
      id: json['id'] as String,
      name: json['name'] as String,
      logoPath: json['logo_path'] as String?,
      bankDetails: BankDetails.fromTenantJson(json),
      profile: BusinessProfile.fromTenantJson(json),
      waterLimits: WaterLimits.fromTenantJson(json),
      brandPrimary: json['brand_primary'] as String?,
      brandAccent: json['brand_accent'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'logo_path': logoPath,
      ...BankDetails.toTenantJson(bankDetails),
      ...profile.toTenantJson(),
      ...waterLimits.toTenantJson(),
      'brand_primary': brandPrimary,
      'brand_accent': brandAccent,
    };
  }
}
