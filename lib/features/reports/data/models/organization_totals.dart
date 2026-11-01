/// All-time figures for Home, summed on the server.
class OrganizationTotals {
  const OrganizationTotals({
    required this.totalBagsProduced,
    required this.totalRevenue,
  });

  final int totalBagsProduced;

  /// From sales that weren't voided.
  final num totalRevenue;

  factory OrganizationTotals.fromJson(Map<String, dynamic> json) {
    return OrganizationTotals(
      totalBagsProduced: (json['total_bags_produced'] as num).toInt(),
      totalRevenue: json['total_revenue'] as num,
    );
  }
}
