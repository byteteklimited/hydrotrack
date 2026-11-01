/// Where customers should pay: printed in the organization's SMS debt
/// reminders. Stored on the organization as three columns that are either
/// all set or all empty.
class BankDetails {
  const BankDetails({
    required this.bankName,
    required this.accountNumber,
    required this.accountName,
  });

  final String bankName;

  /// 10-digit NUBAN.
  final String accountNumber;
  final String accountName;

  /// Null unless all three columns are present on [json] (a `tenants` row).
  static BankDetails? fromTenantJson(Map<String, dynamic> json) {
    final bankName = json['bank_name'] as String?;
    final accountNumber = json['bank_account_number'] as String?;
    final accountName = json['bank_account_name'] as String?;
    if (bankName == null || accountNumber == null || accountName == null) {
      return null;
    }
    return BankDetails(
      bankName: bankName,
      accountNumber: accountNumber,
      accountName: accountName,
    );
  }

  /// The `tenants` columns for these details; [details] null clears them.
  static Map<String, dynamic> toTenantJson(BankDetails? details) {
    return {
      'bank_name': details?.bankName,
      'bank_account_number': details?.accountNumber,
      'bank_account_name': details?.accountName,
    };
  }
}
