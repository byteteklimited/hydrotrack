/// Where organizations pay HydroTrack (set in the admin console).
class BankAccount {
  const BankAccount({
    required this.bankName,
    required this.accountNumber,
    required this.accountName,
  });

  final String bankName;
  final String accountNumber;
  final String accountName;

  /// Null unless all three are set (the server keeps them all or none).
  static BankAccount? fromJson(Map<String, dynamic> json) {
    final bank = json['bank_name'] as String?;
    final number = json['account_number'] as String?;
    final name = json['account_name'] as String?;
    if (bank == null || number == null || name == null) return null;
    return BankAccount(
      bankName: bank,
      accountNumber: number,
      accountName: name,
    );
  }
}
