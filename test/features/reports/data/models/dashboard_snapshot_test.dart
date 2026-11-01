import 'package:flutter_test/flutter_test.dart';
import 'package:hydrotrack/features/reports/data/models/dashboard_snapshot.dart';

void main() {
  group('DashboardSnapshot JSON', () {
    test('fromJson handles a null lowStock', () {
      final snapshot = DashboardSnapshot.fromJson({
        'bags_produced_today': 1200,
        'cash_collected_today': 85000,
        'total_bags_produced': 48000,
        'total_revenue': 9600000,
        'total_customers': 12,
        'money_outside': 240000,
        'overdue_customer_count': 2,
        'low_stock': null,
        'recent_activity': <Map<String, dynamic>>[],
      });
      expect(snapshot.lowStock, isNull);
      expect(snapshot.recentActivity, isEmpty);
    });

    test('round-trips through fromJson(toJson(x))', () {
      const snapshot = DashboardSnapshot(
        bagsProducedToday: 1200,
        cashCollectedToday: 85000,
        totalBagsProduced: 48000,
        totalRevenue: 9600000,
        totalCustomers: 12,
        moneyOutside: 240000,
        overdueCustomerCount: 2,
        cashFlow: [],
        lowStock: LowStockAlert(
          materialName: 'Nylon rolls',
          quantityRemaining: 5,
          unit: 'rolls',
        ),
        recentActivity: [],
      );
      final roundTripped = DashboardSnapshot.fromJson(snapshot.toJson());
      expect(roundTripped.bagsProducedToday, snapshot.bagsProducedToday);
      expect(roundTripped.totalBagsProduced, snapshot.totalBagsProduced);
      expect(roundTripped.totalRevenue, snapshot.totalRevenue);
      expect(roundTripped.totalCustomers, snapshot.totalCustomers);
      expect(roundTripped.lowStock?.materialName, 'Nylon rolls');
    });
  });
}
