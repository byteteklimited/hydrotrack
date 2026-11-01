import '../../../debts/data/models/customer.dart';
import '../../../debts/data/models/ledger_entry.dart';
import '../../../debts/data/repositories/debts_repository.dart';
import '../../../expenses/data/models/expense.dart';
import '../../../expenses/data/repositories/expenses_repository.dart';
import '../../../finance/data/models/cash_entry.dart';
import '../../../finance/data/models/finance_position.dart';
import '../../../finance/data/repositories/finance_repository.dart';
import '../../../inventory/data/models/stock_item.dart';
import '../../../inventory/data/repositories/inventory_repository.dart';
import '../../../production/data/models/production_run.dart';
import '../../../production/data/repositories/production_repository.dart';
import '../../../sales/data/models/sale.dart';
import '../../../sales/data/repositories/sales_repository.dart';
import '../models/report_period.dart';
import '../models/report_summary.dart';

/// True once [dateTime] falls after the entire day of [cutoffDateOnly]
/// has finished — i.e. on or after midnight the following day. Used to
/// "undo" everything that happened after a cutoff by subtracting it back
/// out of an otherwise-current running total.
bool _isAfterCutoffDay(DateTime dateTime, DateTime cutoffDateOnly) {
  return !dateTime.isBefore(cutoffDateOnly.add(const Duration(days: 1)));
}

/// Contract for assembling a period's report.
abstract class ReportsRepository {
  Future<ReportSummary> fetchSummary(ReportPeriod period);
}

/// Builds every section by reading the same repositories each feature
/// screen reads — so a report can never disagree with what's shown on
/// the Dashboard or inside Production/Sales/Debts themselves.
class AggregatingReportsRepository implements ReportsRepository {
  AggregatingReportsRepository({
    required ProductionRepository production,
    required SalesRepository sales,
    required FinanceRepository finance,
    required DebtsRepository debts,
    required InventoryRepository inventory,
    required ExpensesRepository expenses,
  }) : _production = production,
       _sales = sales,
       _finance = finance,
       _debts = debts,
       _inventory = inventory,
       _expenses = expenses;

  final ProductionRepository _production;
  final SalesRepository _sales;
  final FinanceRepository _finance;
  final DebtsRepository _debts;
  final InventoryRepository _inventory;
  final ExpensesRepository _expenses;

  @override
  Future<ReportSummary> fetchSummary(ReportPeriod period) async {
    final previous = period.previous;
    // Everything from the start of the comparison period on: closing
    // cash is worked back from today's position through later entries.
    final from = previous.start;

    final runs = await _production.fetchRuns(from: from);
    final sales = await _sales.fetchSales(from: from);
    final cashEntries = await _finance.fetchEntries(from: from);
    final cashPosition = await _finance.fetchPosition();
    final customers = await _debts.fetchCustomers();
    final stockItems = await _inventory.fetchItems();
    final expenses = await _expenses.fetchExpenses(from: from);

    final salesSection = _buildSales(sales, period, previous);

    return ReportSummary(
      period: period,
      production: _buildProduction(runs, period, previous),
      sales: salesSection,
      cash: await _buildCash(cashEntries, cashPosition, period, previous),
      moneyOutside: await _buildMoneyOutside(customers, period, previous),
      stock: await _buildStock(stockItems, previous),
      profit: _buildProfit(salesSection, sales, expenses, period, previous),
    );
  }

  ProductionReportSection _buildProduction(
    List<ProductionRun> runs,
    ReportPeriod period,
    ReportPeriod previous,
  ) {
    int bagsIn(ReportPeriod p) => runs
        .where((r) => p.contains(r.date))
        .fold<int>(0, (sum, r) => sum + r.quantityProduced);
    int wastageIn(ReportPeriod p) => runs
        .where((r) => p.contains(r.date))
        .fold<int>(0, (sum, r) => sum + r.wastage);

    return ProductionReportSection(
      bagsProduced: bagsIn(period),
      wastage: wastageIn(period),
      previousBagsProduced: bagsIn(previous),
    );
  }

  SalesReportSection _buildSales(
    List<Sale> allSalesIncludingVoided,
    ReportPeriod period,
    ReportPeriod previous,
  ) {
    // Voided sales stay in the sales list/audit trail, but drop out of
    // every total — filtered once here so every figure this method
    // computes (revenue, bags sold, the by-method breakdown) excludes
    // them consistently, instead of each one needing its own filter.
    final allSales = allSalesIncludingVoided.where((s) => !s.isVoided);

    num revenueIn(ReportPeriod p) => allSales
        .where((s) => p.contains(s.dateTime))
        .fold<num>(0, (sum, s) => sum + s.total);

    final inPeriod = allSales
        .where((s) => period.contains(s.dateTime))
        .toList();
    final bagsSold = inPeriod.fold<int>(0, (sum, s) => sum + s.totalBags);
    final byMethod = <PaymentMethod, num>{};
    for (final sale in inPeriod) {
      byMethod.update(
        sale.paymentMethod,
        (sum) => sum + sale.total,
        ifAbsent: () => sale.total,
      );
    }

    return SalesReportSection(
      bagsSold: bagsSold,
      revenue: revenueIn(period),
      revenueByMethod: byMethod,
      previousRevenue: revenueIn(previous),
    );
  }

  Future<CashReportSection> _buildCash(
    List<CashEntry> entries,
    FinancePosition nowPosition,
    ReportPeriod period,
    ReportPeriod previous,
  ) async {
    num cashInHandAsOf(DateTime cutoff) {
      final afterCutoff = entries.where(
        (e) =>
            e.method == PaymentChannel.cash &&
            _isAfterCutoffDay(e.dateTime, cutoff),
      );
      final undoDelta = afterCutoff.fold<num>(
        0,
        (sum, e) => sum + e.signedAmount,
      );
      return nowPosition.cashInHand - undoDelta;
    }

    final inPeriod = entries.where((e) => period.contains(e.dateTime));
    final cashIn = inPeriod
        .where((e) => e.direction == CashDirection.moneyIn)
        .fold<num>(0, (sum, e) => sum + e.amount);
    final cashOut = inPeriod
        .where((e) => e.direction == CashDirection.moneyOut)
        .fold<num>(0, (sum, e) => sum + e.amount);

    return CashReportSection(
      cashIn: cashIn,
      cashOut: cashOut,
      closingCash: cashInHandAsOf(period.end),
      previousClosingCash: cashInHandAsOf(previous.end),
    );
  }

  Future<MoneyOutsideReportSection> _buildMoneyOutside(
    List<Customer> customers,
    ReportPeriod period,
    ReportPeriod previous,
  ) async {
    num balanceAsOf(
      List<LedgerEntry> ledger,
      num currentBalance,
      DateTime cutoff,
    ) {
      final afterCutoff = ledger.where(
        (entry) => _isAfterCutoffDay(entry.date, cutoff),
      );
      // sum of balanceDelta, not a sale-vs-everything-else binary check:
      // opening balance is signed and can move the balance either way,
      // so it can't be folded into the same fixed-direction shape every
      // other type shares.
      final undoDelta = afterCutoff.fold<num>(
        0,
        (sum, entry) => sum + entry.type.balanceDelta(entry.amount),
      );
      return currentBalance - undoDelta;
    }

    // Only a positive balance is "money outside" — a negative one is
    // credit the business owes back to the customer, not debt owed to
    // it. Dashboard and Debts both already sum only positive balances
    // (`customers.where((c) => c.balance > 0)`); this clamps each
    // customer's contribution the same way so the three screens can't
    // disagree whenever any customer is in credit.
    num owingOnly(num balance) => balance > 0 ? balance : 0;

    num opening = 0;
    num closing = 0;
    num previousClosing = 0;
    final dayBeforeStart = period.start.subtract(const Duration(days: 1));

    for (final customer in customers) {
      final ledger = await _debts.fetchLedger(customer.id);
      opening += owingOnly(
        balanceAsOf(ledger, customer.balance, dayBeforeStart),
      );
      closing += owingOnly(balanceAsOf(ledger, customer.balance, period.end));
      previousClosing += owingOnly(
        balanceAsOf(ledger, customer.balance, previous.end),
      );
    }

    return MoneyOutsideReportSection(
      opening: opening,
      closing: closing,
      previousClosing: previousClosing,
    );
  }

  Future<StockReportSection> _buildStock(
    List<StockItem> items,
    ReportPeriod previous,
  ) async {
    final finishedGoods = items.where(
      (item) => item.category == StockCategory.finishedGoods,
    );
    final lowNow = finishedGoods.where((item) => item.isLowStock).toList();

    var previousLowCount = 0;
    for (final item in finishedGoods) {
      final movements = await _inventory.fetchMovements(item.id);
      final afterCutoff = movements.where(
        (m) => _isAfterCutoffDay(m.at, previous.end),
      );
      final undoDelta = afterCutoff.fold<int>(0, (sum, m) => sum + m.quantity);
      final quantityAtCutoff = item.quantityOnHand - undoDelta;
      if (quantityAtCutoff <= item.reorderLevel) previousLowCount++;
    }

    return StockReportSection(
      lowItems: [
        for (final item in lowNow)
          LowStockSummaryItem(
            name: item.name,
            quantityRemaining: item.quantityOnHand,
            unit: item.unit,
          ),
      ],
      previousLowItemCount: previousLowCount,
    );
  }

  ProfitReportSection _buildProfit(
    SalesReportSection salesSection,
    List<Sale> allSales,
    List<Expense> allExpenses,
    ReportPeriod period,
    ReportPeriod previous,
  ) {
    num expensesIn(ReportPeriod p) => allExpenses
        .where(
          (e) =>
              p.contains(e.date) &&
              e.category != ExpenseCategory.materialsPurchase,
        )
        .fold<num>(0, (sum, e) => sum + e.amount);
    num costOfSalesIn(ReportPeriod p) => allSales
        .where((s) => !s.isVoided && p.contains(s.dateTime))
        .expand((s) => s.lines)
        .fold<num>(0, (sum, line) => sum + line.lineCost);

    return ProfitReportSection(
      revenue: salesSection.revenue,
      costOfSales: costOfSalesIn(period),
      expenses: expensesIn(period),
      previousProfit:
          salesSection.previousRevenue -
          costOfSalesIn(previous) -
          expensesIn(previous),
    );
  }
}
