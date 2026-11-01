import '../../../sales/data/models/sale.dart';
import 'report_period.dart';

/// Bags produced and wastage for the period, with the previous period's
/// bag count for comparison.
class ProductionReportSection {
  const ProductionReportSection({
    required this.bagsProduced,
    required this.wastage,
    required this.previousBagsProduced,
  });

  final int bagsProduced;
  final int wastage;
  final int previousBagsProduced;
}

/// Bags sold and revenue for the period, broken down by how it was paid.
class SalesReportSection {
  const SalesReportSection({
    required this.bagsSold,
    required this.revenue,
    required this.revenueByMethod,
    required this.previousRevenue,
  });

  final int bagsSold;
  final num revenue;
  final Map<PaymentMethod, num> revenueByMethod;
  final num previousRevenue;
}

/// Cash moved during the period, and the cash-in-hand position at its
/// close.
class CashReportSection {
  const CashReportSection({
    required this.cashIn,
    required this.cashOut,
    required this.closingCash,
    required this.previousClosingCash,
  });

  final num cashIn;
  final num cashOut;
  final num closingCash;
  final num previousClosingCash;
}

/// Total customer debt at the start and end of the period.
class MoneyOutsideReportSection {
  const MoneyOutsideReportSection({
    required this.opening,
    required this.closing,
    required this.previousClosing,
  });

  final num opening;
  final num closing;
  final num previousClosing;
}

/// One finished-goods item currently below its reorder point.
class LowStockSummaryItem {
  const LowStockSummaryItem({
    required this.name,
    required this.quantityRemaining,
    required this.unit,
  });

  final String name;
  final int quantityRemaining;
  final String unit;
}

/// A snapshot of finished goods running low, right now.
class StockReportSection {
  const StockReportSection({
    required this.lowItems,
    required this.previousLowItemCount,
  });

  final List<LowStockSummaryItem> lowItems;
  final int previousLowItemCount;
}

/// The bottom line: revenue minus expenses, shown as the actual
/// subtraction rather than a single opaque figure.
class ProfitReportSection {
  const ProfitReportSection({
    required this.revenue,
    required this.expenses,
    required this.previousProfit,
  });

  final num revenue;
  final num expenses;
  final num previousProfit;

  num get profit => revenue - expenses;
}

/// The full report for one period: profit first (the answer the owner
/// wants), then the sections that explain it.
class ReportSummary {
  const ReportSummary({
    required this.period,
    required this.profit,
    required this.sales,
    required this.production,
    required this.cash,
    required this.moneyOutside,
    required this.stock,
  });

  final ReportPeriod period;
  final ProfitReportSection profit;
  final SalesReportSection sales;
  final ProductionReportSection production;
  final CashReportSection cash;
  final MoneyOutsideReportSection moneyOutside;
  final StockReportSection stock;
}
