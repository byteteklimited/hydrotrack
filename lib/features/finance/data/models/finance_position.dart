/// The business's current running position — how much cash is physically
/// on hand versus sitting in the bank.
class FinancePosition {
  const FinancePosition({required this.cashInHand, required this.bankBalance});

  final num cashInHand;
  final num bankBalance;
}
