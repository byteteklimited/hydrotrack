/// A HydroTrack plan (`plans`, migration 0036). Every plan has every
/// feature; they differ in price, staff and locations.
class Plan {
  const Plan({
    required this.key,
    required this.name,
    required this.description,
    required this.monthlyPrice,
    required this.isPopular,
    this.maxStaff,
    this.maxLocations,
  });

  /// "starter", "standard" or "premium".
  final String key;
  final String name;

  /// Who it's for, e.g. "For growing factories".
  final String description;
  final num monthlyPrice;

  /// Staff who aren't owners (open invites count); null means unlimited.
  final int? maxStaff;

  /// Factories and depots; null means unlimited.
  final int? maxLocations;
  final bool isPopular;

  String get staffLimit => maxStaff == null
      ? 'Unlimited staff users'
      : 'Up to $maxStaff staff users';

  String get locationLimit => switch (maxLocations) {
    null => 'Multiple factories and depots',
    1 => 'One factory',
    final count => 'Up to $count factories or depots',
  };

  factory Plan.fromJson(Map<String, dynamic> json) => Plan(
    key: json['key'] as String,
    name: json['name'] as String,
    description: json['description'] as String,
    monthlyPrice: json['monthly_price'] as num,
    maxStaff: json['max_staff'] as int?,
    maxLocations: json['max_locations'] as int?,
    isPopular: json['is_popular'] as bool? ?? false,
  );
}
