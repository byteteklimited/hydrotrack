/// One organization (tenant) — a water factory business using HydroTrack.
/// Every business record belongs to exactly one organization.
class Organization {
  const Organization({required this.id, required this.name, this.logoPath});

  final String id;
  final String name;

  /// Path inside the private `tenant-files` storage bucket, if a logo
  /// has been uploaded.
  final String? logoPath;

  factory Organization.fromJson(Map<String, dynamic> json) {
    return Organization(
      id: json['id'] as String,
      name: json['name'] as String,
      logoPath: json['logo_path'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'name': name, 'logo_path': logoPath};
  }
}
