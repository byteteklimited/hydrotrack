/// The one HydroTrack plan (`platform_settings`).
class PlatformSettings {
  const PlatformSettings({
    required this.trialDays,
    required this.graceDays,
    this.monthlyPrice,
    this.paymentInstructions,
  });

  /// Null until set.
  final num? monthlyPrice;

  /// For organizations created from now on.
  final int trialDays;

  /// Days after the trial or paid time before an organization is
  /// read-only (applies to everyone).
  final int graceDays;

  /// Shown to owners under "How to pay".
  final String? paymentInstructions;

  factory PlatformSettings.fromJson(Map<String, dynamic> json) =>
      PlatformSettings(
        monthlyPrice: json['monthly_price'] as num?,
        trialDays: json['trial_days'] as int,
        graceDays: json['grace_days'] as int,
        paymentInstructions: json['payment_instructions'] as String?,
      );

  Map<String, dynamic> toRpcParams() => {
    'p_monthly_price': monthlyPrice ?? 0,
    'p_trial_days': trialDays,
    'p_grace_days': graceDays,
    'p_payment_instructions': paymentInstructions,
  };
}
