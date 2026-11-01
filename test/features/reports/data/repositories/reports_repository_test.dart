import 'package:flutter_test/flutter_test.dart';
import 'package:hydrotrack/features/debts/data/models/customer.dart';
import 'package:hydrotrack/features/expenses/data/models/expense.dart';
import 'package:hydrotrack/features/finance/data/models/cash_entry.dart';
import 'package:hydrotrack/features/finance/data/models/finance_position.dart';
import 'package:hydrotrack/features/inventory/data/models/stock_item.dart';
import 'package:hydrotrack/features/production/data/models/production_run.dart';
import 'package:hydrotrack/features/reports/data/models/report_period.dart';
import 'package:hydrotrack/features/reports/data/repositories/reports_repository.dart';
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

Sale _sale({
  required DateTime dateTime,
  required num total,
  required int bags,
  num? balance,
  bool voided = false,
}) => Sale(
  id: 'sale-${dateTime.toIso8601String()}-$total',
  dateTime: dateTime,
  customerType: CustomerType.walkIn,
  lines: [
    SaleLine(product: sachet50cl, quantity: bags, unitPrice: total / bags),
  ],
  total: total,
  amountPaid: total - (balance ?? 0),
  paymentMethod: PaymentMethod.cash,
  balance: balance ?? 0,
  recordedBy: 'Tester',
  voidedAt: voided ? dateTime.add(const Duration(hours: 1)) : null,
  voidedBy: voided ? 'Admin User' : null,
  voidReason: voided ? 'Entered twice by mistake' : null,
);

Customer _customer({required String id, required num balance}) => Customer(
  id: id,
  name: id,
  phone: '08000000000',
  area: 'Kaduna',
  creditLimit: 50000,
  balance: balance,
);

void main() {
  final today = DateTime.now();
  final yesterday = today.subtract(const Duration(days: 1));

  AggregatingReportsRepository build({
    List<ProductionRun> runs = const [],
    List<Sale> sales = const [],
    List<CashEntry> cashEntries = const [],
    FinancePosition position = const FinancePosition(
      cashInHand: 0,
      bankBalance: 0,
    ),
    List<Customer> customers = const [],
    List<StockItem> stockItems = const [],
    List<Expense> expenses = const [],
  }) {
    return AggregatingReportsRepository(
      production: FakeProductionRepository(runs),
      sales: FakeSalesRepository(sales),
      finance: FakeFinanceRepository(cashEntries, position),
      debts: FakeDebtsRepository(customers),
      inventory: FakeInventoryRepository(stockItems),
      expenses: FakeExpensesRepository(expenses),
    );
  }

  group("AggregatingReportsRepository — invariant #10: every Reports total "
      'equals the matching module total for the same period', () {
    test('production.bagsProduced for "today" matches only today\'s runs '
        '— the exact figure Home/Production would also compute', () async {
      final repo = build(
        runs: [
          _run(date: today, quantityProduced: 300),
          _run(date: today, quantityProduced: 200),
          _run(date: yesterday, quantityProduced: 999),
        ],
      );

      final summary = await repo.fetchSummary(ReportPeriod.today());

      expect(summary.production.bagsProduced, 500);
    });

    test(
      'sales.revenue/bagsSold for "today" matches only today\'s sales',
      () async {
        final repo = build(
          sales: [
            _sale(dateTime: today, total: 8000, bags: 20),
            _sale(dateTime: today, total: 70000, bags: 200),
            _sale(dateTime: yesterday, total: 999999, bags: 1),
          ],
        );

        final summary = await repo.fetchSummary(ReportPeriod.today());

        expect(summary.sales.revenue, 78000);
        expect(summary.sales.bagsSold, 220);
      },
    );

    test('moneyOutside.closing matches the same positive-balances-only sum '
        'Dashboard and Debts both compute', () async {
      final repo = build(
        customers: [
          _customer(id: 'owing', balance: 20000),
          _customer(id: 'in-credit', balance: -10000),
        ],
      );

      final summary = await repo.fetchSummary(ReportPeriod.today());

      expect(summary.moneyOutside.closing, 20000);
    });
  });

  group(
    'AggregatingReportsRepository — invariant #8: net cashflow for a period '
    'equals cash in minus cash out',
    () {
      test('closing cash position minus previous closing equals cashIn minus '
          'cashOut for the same period', () async {
        final repo = build(
          cashEntries: [
            _cashEntry(
              dateTime: today,
              direction: CashDirection.moneyIn,
              amount: 58000,
            ),
            _cashEntry(
              dateTime: today,
              direction: CashDirection.moneyOut,
              amount: 165000,
            ),
          ],
          position: const FinancePosition(cashInHand: -107000, bankBalance: 0),
        );

        final summary = await repo.fetchSummary(ReportPeriod.today());
        final netCashflow = summary.cash.cashIn - summary.cash.cashOut;
        final positionDelta =
            summary.cash.closingCash - summary.cash.previousClosingCash;

        expect(netCashflow, -107000);
        expect(positionDelta, netCashflow);
      });
    },
  );

  group('Standalone accounting identity — invariant #5: revenue == cash '
      'collected + money outside - customer credit (zero opening balances, '
      'no write-offs)', () {
    test('holds for the test-scenario-style Day 1 numbers', () async {
      // Mirrors the reconciliation brief's own Day 1: a cash sale and a
      // part-paid distributor sale, nothing else yet.
      final repo = build(
        sales: [
          _sale(dateTime: today, total: 8000, bags: 20), // cash, fully paid
          _sale(
            dateTime: today,
            total: 70000,
            bags: 200,
            balance: 20000,
          ), // distributor, part-paid
        ],
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
        ],
        customers: [_customer(id: 'distributor', balance: 20000)],
      );

      final summary = await repo.fetchSummary(ReportPeriod.today());

      final revenue = summary.sales.revenue; // 78000
      final cashCollected = summary.cash.cashIn; // 58000
      final moneyOutside = summary.moneyOutside.closing; // 20000
      const customerCredit = 0;

      expect(revenue, cashCollected + moneyOutside - customerCredit);
    });
  });

  group(
    'Invariant #11: voiding a sale drops it out of every affected total',
    () {
      test(
        'a voided sale contributes nothing to revenue or bags sold',
        () async {
          final repo = build(
            sales: [
              _sale(dateTime: today, total: 8000, bags: 20),
              _sale(dateTime: today, total: 70000, bags: 200, voided: true),
            ],
          );

          final summary = await repo.fetchSummary(ReportPeriod.today());

          expect(summary.sales.revenue, 8000);
          expect(summary.sales.bagsSold, 20);
        },
      );
    },
  );
}
