// Minimal fake repositories for testing `AggregatingDashboardRepository`
// and `AggregatingReportsRepository` against fixed fixture data, without
// a Supabase client — both aggregators accept any `*Repository`
// implementation via their constructors, so these stand in for the real
// `Supabase*Repository` ones. Only the read methods either aggregator
// actually calls are meaningfully implemented; every write throws, since
// a read-only aggregation test should never hit one.
import 'package:hydrotrack/features/debts/data/models/customer.dart';
import 'package:hydrotrack/features/debts/data/models/ledger_entry.dart';
import 'package:hydrotrack/features/debts/data/models/recent_payment.dart';
import 'package:hydrotrack/features/debts/data/repositories/debts_repository.dart';
import 'package:hydrotrack/features/distribution/data/models/driver.dart';
import 'package:hydrotrack/features/distribution/data/models/load_out.dart';
import 'package:hydrotrack/features/distribution/data/models/vehicle.dart';
import 'package:hydrotrack/features/distribution/data/repositories/distribution_repository.dart';
import 'package:hydrotrack/features/expenses/data/models/expense.dart';
import 'package:hydrotrack/features/expenses/data/repositories/expenses_repository.dart';
import 'package:hydrotrack/features/finance/data/models/cash_entry.dart';
import 'package:hydrotrack/features/finance/data/models/finance_position.dart';
import 'package:hydrotrack/features/finance/data/repositories/finance_repository.dart';
import 'package:hydrotrack/features/inventory/data/models/stock_batch.dart';
import 'package:hydrotrack/features/inventory/data/models/stock_item.dart';
import 'package:hydrotrack/features/inventory/data/models/stock_movement.dart';
import 'package:hydrotrack/features/inventory/data/repositories/inventory_repository.dart';
import 'package:hydrotrack/features/production/data/models/production_run.dart';
import 'package:hydrotrack/features/production/data/repositories/production_repository.dart';
import 'package:hydrotrack/features/sales/data/models/sale.dart';
import 'package:hydrotrack/features/sales/data/repositories/sales_repository.dart';

Never _unused() => throw UnimplementedError('not needed by this test');

class FakeProductionRepository implements ProductionRepository {
  FakeProductionRepository(this.runs);
  final List<ProductionRun> runs;

  @override
  Future<List<ProductionRun>> fetchRuns() async => runs;

  @override
  Future<ProductionRun> recordRun(ProductionRun run, {DateTime? expiryDate}) =>
      _unused();
  @override
  Future<ProductionRun> updateRun(ProductionRun run, {DateTime? expiryDate}) =>
      _unused();
  @override
  Future<void> deleteRun(String runId) => _unused();
}

class FakeSalesRepository implements SalesRepository {
  FakeSalesRepository(this.sales);
  final List<Sale> sales;

  @override
  Future<List<Sale>> fetchSales() async => sales;

  @override
  Future<List<String>> fetchDistributorNames() => _unused();
  @override
  Future<Sale> recordSale(Sale sale, {PaymentChannel? paidChannel}) =>
      _unused();
  @override
  Future<void> voidSale({required String saleId, required String reason}) =>
      _unused();
}

class FakeFinanceRepository implements FinanceRepository {
  FakeFinanceRepository(this.entries, this.position);
  final List<CashEntry> entries;
  final FinancePosition position;

  @override
  Future<List<CashEntry>> fetchEntries() async => entries;
  @override
  Future<FinancePosition> fetchPosition() async => position;

  @override
  Future<void> recordEntry(CashEntry entry) => _unused();
}

class FakeDebtsRepository implements DebtsRepository {
  FakeDebtsRepository(this.customers, {this.ledgersByCustomerId = const {}});
  final List<Customer> customers;
  final Map<String, List<LedgerEntry>> ledgersByCustomerId;

  @override
  Future<List<Customer>> fetchCustomers() async => customers;
  @override
  Future<List<LedgerEntry>> fetchLedger(String customerId) async =>
      ledgersByCustomerId[customerId] ?? const [];
  @override
  Future<RecentPayment?> fetchMostRecentPayment() async => null;

  @override
  Future<Customer> recordPayment({
    required String customerId,
    required num amount,
    required PaymentChannel channel,
    required DateTime date,
    String? note,
  }) => _unused();
  @override
  Future<Customer> updateCreditLimit({
    required String customerId,
    required num newLimit,
  }) => _unused();
  @override
  Future<Customer> createCustomer({
    required String name,
    required String phone,
    required String area,
    required num creditLimit,
  }) => _unused();
  @override
  Future<Customer> addOpeningBalance({
    required String customerId,
    required num amount,
    required String reason,
  }) => _unused();
  @override
  Future<Customer> writeOffDebt({
    required String customerId,
    required num amount,
    required String reason,
  }) => _unused();
}

class FakeInventoryRepository implements InventoryRepository {
  FakeInventoryRepository(this.items);
  final List<StockItem> items;

  @override
  Future<List<StockItem>> fetchItems() async => items;
  @override
  Future<List<StockMovement>> fetchMovements(String itemId) async => const [];
  @override
  Future<List<StockBatch>> fetchBatches(String itemId) async => const [];
  @override
  Future<List<StockBatch>> fetchActiveBatches() async => const [];
  @override
  Future<DateTime?> fetchLastStockCountDate() async => null;

  @override
  Future<void> addStock({
    required String itemId,
    required int quantity,
    String? note,
    DateTime? expiryDate,
  }) => _unused();
  @override
  Future<void> adjustCount({
    required String itemId,
    required int newCount,
    required String note,
  }) => _unused();
  @override
  Future<StockItem> createItem({
    required String name,
    required String unit,
    required int reorderLevel,
  }) => _unused();
  @override
  Future<StockItem> updateItemDetails({
    required String itemId,
    required String name,
    required String unit,
    required int reorderLevel,
  }) => _unused();
  @override
  Future<void> deleteItem(String itemId) => _unused();
}

class FakeExpensesRepository implements ExpensesRepository {
  FakeExpensesRepository(this.expenses);
  final List<Expense> expenses;

  @override
  Future<List<Expense>> fetchExpenses() async => expenses;
  @override
  Future<void> recordExpense(Expense expense) => _unused();
}

class FakeDistributionRepository implements DistributionRepository {
  FakeDistributionRepository({
    this.loadOuts = const [],
    this.drivers = const [],
    this.vehicles = const [],
  });
  final List<LoadOut> loadOuts;
  final List<Driver> drivers;
  final List<Vehicle> vehicles;

  @override
  Future<List<LoadOut>> fetchLoadOuts() async => loadOuts;
  @override
  Future<List<Driver>> fetchDrivers() async => drivers;
  @override
  Future<List<Vehicle>> fetchVehicles() async => vehicles;

  @override
  Future<Driver> createDriver({required String name, required String phone}) =>
      _unused();
  @override
  Future<Vehicle> createVehicle({required String name}) => _unused();
  @override
  Future<LoadOut> recordLoadOut(LoadOut loadOut) => _unused();
  @override
  Future<LoadOut> settleTrip({
    required String loadOutId,
    required int bagsSold,
    required int bagsReturned,
    required int bagsDamaged,
    required num cashReturned,
    String? discrepancyNote,
    CustomerType customerType = CustomerType.walkIn,
    String? customerName,
    num? unitPrice,
    num? amountPaid,
    PaymentMethod paymentMethod = PaymentMethod.cash,
    PaymentChannel? paidChannel,
  }) => _unused();
}
