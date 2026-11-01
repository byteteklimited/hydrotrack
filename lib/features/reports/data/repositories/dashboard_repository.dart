import '../../../distribution/data/repositories/distribution_repository.dart';
import '../../../finance/data/models/cash_entry.dart';
import '../../../finance/data/repositories/finance_repository.dart';
import '../../../inventory/data/models/stock_item.dart';
import '../../../inventory/data/repositories/inventory_repository.dart';
import '../../../production/data/repositories/production_repository.dart';
import '../../../debts/data/repositories/debts_repository.dart';
import '../../../sales/data/repositories/sales_repository.dart';
import '../models/dashboard_snapshot.dart';

/// Contract for fetching the dashboard snapshot.
abstract class DashboardRepository {
  Future<DashboardSnapshot> fetchToday();
}

/// Composes today's snapshot from the same repositories every other
/// feature reads — so the dashboard and Reports can never disagree on
/// today's numbers. Given those (current-organization) repositories by its
/// provider rather than building its own, so it's tenant-scoped exactly
/// like they are.
class AggregatingDashboardRepository implements DashboardRepository {
  AggregatingDashboardRepository({
    required ProductionRepository production,
    required FinanceRepository finance,
    required DebtsRepository debts,
    required InventoryRepository inventory,
    required SalesRepository sales,
    required DistributionRepository distribution,
  }) : _production = production,
       _finance = finance,
       _debts = debts,
       _inventory = inventory,
       _sales = sales,
       _distribution = distribution;

  final ProductionRepository _production;
  final FinanceRepository _finance;
  final DebtsRepository _debts;
  final InventoryRepository _inventory;
  final SalesRepository _sales;
  final DistributionRepository _distribution;

  static const _networkDelay = Duration(milliseconds: 600);

  @override
  Future<DashboardSnapshot> fetchToday() async {
    await Future.delayed(_networkDelay);
    final today = DateTime.now();
    bool isToday(DateTime dt) =>
        dt.year == today.year && dt.month == today.month && dt.day == today.day;

    final runs = await _production.fetchRuns();
    final cashEntries = await _finance.fetchEntries();
    final customers = await _debts.fetchCustomers();
    final items = await _inventory.fetchItems();
    final sales = await _sales.fetchSales();
    final loadOuts = await _distribution.fetchLoadOuts();
    final drivers = await _distribution.fetchDrivers();
    final vehicles = await _distribution.fetchVehicles();
    final lastPayment = await _debts.fetchMostRecentPayment();

    final bagsProducedToday = runs
        .where((r) => isToday(r.date))
        .fold<int>(0, (sum, r) => sum + r.quantityProduced);
    final cashCollectedToday = cashEntries
        .where(
          (e) => isToday(e.dateTime) && e.direction == CashDirection.moneyIn,
        )
        .fold<num>(0, (sum, e) => sum + e.amount);
    final owing = customers.where((c) => c.balance > 0);
    final moneyOutside = owing.fold<num>(0, (sum, c) => sum + c.balance);
    final overdueCustomerCount = owing.where((c) => c.isOverdue).length;

    final totalBagsProduced = runs.fold<int>(
      0,
      (sum, r) => sum + r.quantityProduced,
    );
    final totalRevenue = sales
        .where((s) => !s.isVoided)
        .fold<num>(0, (sum, s) => sum + s.total);
    final totalCustomers = customers.length;

    bool isSameDate(DateTime a, DateTime b) =>
        a.year == b.year && a.month == b.month && a.day == b.day;
    final todayDateOnly = DateTime(today.year, today.month, today.day);
    final cashFlow =
        [for (var i = 6; i >= 0; i--) todayDateOnly.subtract(Duration(days: i))]
            .map((day) {
              final dayEntries = cashEntries.where(
                (e) => isSameDate(e.dateTime, day),
              );
              return CashFlowDay(
                date: day,
                moneyIn: dayEntries
                    .where((e) => e.direction == CashDirection.moneyIn)
                    .fold<num>(0, (sum, e) => sum + e.amount),
                moneyOut: dayEntries
                    .where((e) => e.direction == CashDirection.moneyOut)
                    .fold<num>(0, (sum, e) => sum + e.amount),
              );
            })
            .toList();

    final lowRawMaterial = items
        .where((i) => i.category == StockCategory.rawMaterial && i.isLowStock)
        .toList();
    final lowStock = lowRawMaterial.isEmpty
        ? null
        : LowStockAlert(
            materialName: lowRawMaterial.first.name,
            quantityRemaining: lowRawMaterial.first.quantityOnHand,
            unit: lowRawMaterial.first.unit,
          );

    final activity = <ActivityEntry>[
      if (runs.isNotEmpty)
        ActivityEntry(
          time: runs.first.recordedAt,
          description:
              'Production run logged — ${runs.first.machine}, ${runs.first.quantityProduced} bags',
          actor: runs.first.recordedBy,
          kind: ActivityKind.production,
        ),
      if (sales.isNotEmpty)
        ActivityEntry(
          time: sales.first.dateTime,
          description:
              'Sale recorded — ${sales.first.totalBags} bags to ${sales.first.customerName ?? 'walk-in'}',
          actor: sales.first.recordedBy,
          kind: ActivityKind.sale,
        ),
      if (loadOuts.isNotEmpty)
        ActivityEntry(
          time: loadOuts.first.dateTime,
          description:
              'Load-out confirmed — ${loadOuts.first.bagsLoaded} bags, '
              '${vehicles.firstWhere((v) => v.id == loadOuts.first.vehicleId).name}',
          actor: drivers
              .firstWhere((d) => d.id == loadOuts.first.driverId)
              .name,
          kind: ActivityKind.loadOut,
        ),
    ]..sort((a, b) => b.time.compareTo(a.time));

    return DashboardSnapshot(
      bagsProducedToday: bagsProducedToday,
      cashCollectedToday: cashCollectedToday,
      totalBagsProduced: totalBagsProduced,
      totalRevenue: totalRevenue,
      totalCustomers: totalCustomers,
      moneyOutside: moneyOutside,
      overdueCustomerCount: overdueCustomerCount,
      cashFlow: cashFlow,
      lowStock: lowStock,
      lastPayment: lastPayment,
      recentActivity: activity,
    );
  }
}
