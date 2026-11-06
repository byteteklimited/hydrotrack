import '../../../subscriptions/data/models/bank_account.dart';

/// HydroTrack-wide settings (`platform_settings`): trial and grace length
/// and where organizations pay. Plan prices live on each plan.
class PlatformSettings {
  const PlatformSettings({
    required this.trialDays,
    required this.graceDays,
    this.bankAccount,
    this.paymentInstructions,
  });

  /// For organizations created from now on.
  final int trialDays;

  /// Days after the trial or paid time before an organization is
  /// read-only (applies to everyone).
  final int graceDays;

  /// Shown to owners under "How to pay"; null until set.
  final BankAccount? bankAccount;

  /// Anything else owners should know, e.g. where to send the receipt.
  final String? paymentInstructions;

  factory PlatformSettings.fromJson(Map<String, dynamic> json) =>
      PlatformSettings(
        trialDays: json['trial_days'] as int,
        graceDays: json['grace_days'] as int,
        bankAccount: BankAccount.fromJson(json),
        paymentInstructions: json['payment_instructions'] as String?,
      );

  Map<String, dynamic> toRpcParams() => {
    'p_trial_days': trialDays,
    'p_grace_days': graceDays,
    'p_bank_name': bankAccount?.bankName,
    'p_account_number': bankAccount?.accountNumber,
    'p_account_name': bankAccount?.accountName,
    'p_payment_instructions': paymentInstructions,
  };
}
