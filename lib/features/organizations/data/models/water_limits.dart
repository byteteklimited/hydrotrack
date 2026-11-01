/// What a water test must read to pass (migration 0025). Defaults are the
/// Nigerian standard for drinking water, NIS 554.
class WaterLimits {
  const WaterLimits({
    this.phMin = defaultPhMin,
    this.phMax = defaultPhMax,
    this.tdsMax = defaultTdsMax,
    this.chlorineMin = defaultChlorineMin,
    this.chlorineMax = defaultChlorineMax,
  });

  static const defaultPhMin = 6.5;
  static const defaultPhMax = 8.5;
  static const defaultTdsMax = 500;
  static const defaultChlorineMin = 0.2;
  static const defaultChlorineMax = 0.25;

  final num phMin;
  final num phMax;

  /// mg/L
  final num tdsMax;

  /// Residual chlorine, mg/L.
  final num chlorineMin;
  final num chlorineMax;

  /// Why readings fail, worded as the server words them; empty = passed.
  List<String> problems({
    required num ph,
    required num tds,
    required num chlorine,
  }) => [
    if (ph < phMin || ph > phMax)
      'pH ${plain(ph)} (allowed ${plain(phMin)}–${plain(phMax)})',
    if (tds > tdsMax) 'TDS ${plain(tds)} mg/L (max ${plain(tdsMax)})',
    if (chlorine < chlorineMin || chlorine > chlorineMax)
      'chlorine ${plain(chlorine)} mg/L '
          '(allowed ${plain(chlorineMin)}–${plain(chlorineMax)})',
  ];

  /// A number without trailing zeros: 9.10 → "9.1", 500.0 → "500".
  static String plain(num value) {
    final text = value.toString();
    if (!text.contains('.')) return text;
    return text.replaceFirst(RegExp(r'\.?0+$'), '');
  }

  factory WaterLimits.fromTenantJson(Map<String, dynamic> json) => WaterLimits(
    phMin: json['water_ph_min'] as num? ?? defaultPhMin,
    phMax: json['water_ph_max'] as num? ?? defaultPhMax,
    tdsMax: json['water_tds_max'] as num? ?? defaultTdsMax,
    chlorineMin: json['water_chlorine_min'] as num? ?? defaultChlorineMin,
    chlorineMax: json['water_chlorine_max'] as num? ?? defaultChlorineMax,
  );

  Map<String, dynamic> toTenantJson() => {
    'water_ph_min': phMin,
    'water_ph_max': phMax,
    'water_tds_max': tdsMax,
    'water_chlorine_min': chlorineMin,
    'water_chlorine_max': chlorineMax,
  };
}
