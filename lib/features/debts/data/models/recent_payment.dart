/// The most recent payment received from any customer — who paid, how
/// much, and when. Used by the dashboard's "last payment" card.
class RecentPayment {
  const RecentPayment({
    required this.customerName,
    required this.amount,
    required this.date,
  });

  final String customerName;
  final num amount;
  final DateTime date;
}
