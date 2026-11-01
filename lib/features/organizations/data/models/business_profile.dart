/// The organization's contact and registration details, all optional,
/// printed under its name on receipts and report exports.
class BusinessProfile {
  const BusinessProfile({
    this.address,
    this.phone,
    this.email,
    this.rcNumber,
    this.nafdacNumber,
  });

  final String? address;
  final String? phone;
  final String? email;

  /// CAC registration (RC) number.
  final String? rcNumber;
  final String? nafdacNumber;

  bool get isComplete => address != null && phone != null && rcNumber != null;

  /// The lines under the business name, e.g. "Tel: 0803… · info@…".
  List<String> get headerLines => [
    ?address,
    if (phone != null || email != null)
      [if (phone != null) 'Tel: $phone', ?email].join(' · '),
    if (rcNumber != null || nafdacNumber != null)
      [
        if (rcNumber != null) 'RC: $rcNumber',
        if (nafdacNumber != null) 'NAFDAC: $nafdacNumber',
      ].join(' · '),
  ];

  factory BusinessProfile.fromTenantJson(Map<String, dynamic> json) {
    return BusinessProfile(
      address: json['address'] as String?,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      rcNumber: json['rc_number'] as String?,
      nafdacNumber: json['nafdac_number'] as String?,
    );
  }

  Map<String, dynamic> toTenantJson() => {
    'address': address,
    'phone': phone,
    'email': email,
    'rc_number': rcNumber,
    'nafdac_number': nafdacNumber,
  };
}
