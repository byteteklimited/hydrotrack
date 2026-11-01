import 'package:flutter_test/flutter_test.dart';
import 'package:hydrotrack/features/debts/data/models/customer.dart';
import 'package:hydrotrack/features/finance/data/models/cash_entry.dart';
import 'package:hydrotrack/features/finance/data/models/finance_position.dart';
import 'package:hydrotrack/features/production/data/models/production_run.dart';
import 'package:hydrotrack/features/reports/data/repositories/dashboard_repository.dart';
import 'package:hydrotrack/features/sales/data/models/sale.dart';
import 'package:hydrotrack/features/sales/data/models/sale_line.dart';

import '../../fakes.dart';

import '../../../../helpers/test_products.dart';

ProductionRun _run({required DateTime date, required int quantityProduced}) =>
    ProductionRun(
      id: 'run-${date.toIso8601String()}-$quantityProduced',
      date: date,
      shift: ProductionShift.morning,
      machine: 'Machine 1',
      operatorName: 'Operator',
      product: sachet50cl,
      quantityProduced: quantityProduced,
      wastage: 0,
      recordedBy: 'Tester',
      recordedAt: date,
    );

CashEntry _cashEntry({
  required DateTime dateTime,
  required CashDirection direction,
  required num amount,
}) => CashEntry(
  id: 'cash-${dateTime.toIso8601String()}-$amount',
  dateTime: dateTime,
  direction: direction,
  source: CashSource.sales,
  amount: amount,
  method: PaymentChannel.cash,
  recordedBy: 'Tester',
);

Customer _customer({required String id, required num balance}) => Customer(
  id: id,
  name: id,
  phone: '08000000000',
  area: 'Kaduna',
  creditLimit: 50000,
  balance: balance,
);

Sale _sale({
  required DateTime dateTime,
  required num total,
  bool voided = false,
}) => Sale(
  id: 'sale-${dateTime.toIso8601String()}-$total',
  dateTime: dateTime,
  customerType: CustomerType.walkIn,
  lines: [SaleLine(product: sachet50cl, quantity: 1, unitPrice: total)],
  total: total,
  amountPaid: total,
  paymentMethod: PaymentMethod.cash,
  balance: 0,
  recordedBy: 'Tester',
  voidedAt: voided ? dateTime.add(const Duration(hours: 1)) : null,
  voidedBy: voided ? 'Admin User' : null,
  voidReason: voided ? 'Entered twice by mistake' : null,
);

void main() {
  final today = DateTime.now();
  final yesterday = today.subtract(const Duration(days: 1));

  AggregatingDashboardRepository build({
    List<ProductionRun> runs = const [],
    List<CashEntry> cashEntries = const [],
    List<Customer> customers = const [],
    List<Sale> sales = const [],
  }) {
    return AggregatingDashboardRepository(
      production: FakeProductionRepository(runs),
      finance: FakeFinanceRepository(
        cashEntries,
        const FinancePosition(cashInHand: 0, bankBalance: 0),
      ),
      debts: FakeDebtsRepository(customers),
      inventory: FakeInventoryRepository(const []),
      sales: FakeSalesRepository(sales),
      distribution: FakeDistributionRepository(),
    );
  }

  group('AggregatingDashboardRepository — invariant #1: bagsProducedToday', () {
    test('sums only runs dated today, ignoring earlier days', () async {
      final repo = build(
        runs: [
          _run(date: today, quantityProduced: 300),
          _run(date: today, quantityProduced: 200),
          _run(date: yesterday, quantityProduced: 999),
        ],
      );

      final snapshot = await repo.fetchToday();

      expect(snapshot.bagsProducedToday, 500);
      expect(snapshot.totalBagsProduced, 1499);
    });
  });

  group('AggregatingDashboardRepository — invariant #7: cashCollectedToday == '
      "sum of today's incoming payment records", () {
    test('sums only today\'s money-in entries, excluding money-out and '
        'earlier days', () async {
      final repo = build(
        cashEntries: [
          _cashEntry(
            dateTime: today,
            direction: CashDirection.moneyIn,
            amount: 8000,
          ),
          _cashEntry(
            dateTime: today,
            direction: CashDirection.moneyIn,
            amount: 50000,
          ),
          _cashEntry(
            dateTime: today,
            direction: CashDirection.moneyOut,
            amount: 15000,
          ),
          _cashEntry(
            dateTime: yesterday,
            direction: CashDirection.moneyIn,
            amount: 999999,
          ),
        ],
      );

      final snapshot = await repo.fetchToday();

      expect(snapshot.cashCollectedToday, 58000);
    });
  });

  group('AggregatingDashboardRepository — invariant #4: moneyOutside == sum of '
      'positive Customer balances only', () {
    test('never includes a negative (in-credit) or zero balance', () async {
      final repo = build(
        customers: [
          _customer(id: 'owing', balance: 20000),
          _customer(id: 'in-credit', balance: -10000),
          _customer(id: 'settled', balance: 0),
        ],
      );

      final snapshot = await repo.fetchToday();

      expect(snapshot.moneyOutside, 20000);
    });
  });

  group('AggregatingDashboardRepository — invariant #11: voiding a sale drops '
      'it out of totalRevenue', () {
    test('a voided sale contributes nothing to totalRevenue', () async {
      final repo = build(
        sales: [
          _sale(dateTime: today, total: 8000),
          _sale(dateTime: today, total: 70000, voided: true),
        ],
      );

      final snapshot = await repo.fetchToday();

      expect(snapshot.totalRevenue, 8000);
    });
  });
}
