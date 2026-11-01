import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../debts/data/providers/debts_providers.dart';
import '../../../expenses/data/providers/expenses_providers.dart';
import '../../../finance/data/providers/finance_providers.dart';
import '../../../inventory/data/providers/inventory_providers.dart';
import '../../../production/data/providers/production_providers.dart';
import '../../../sales/data/providers/sales_providers.dart';
import '../models/report_period.dart';
import '../models/report_summary.dart';
import '../repositories/reports_repository.dart';

/// The active [ReportsRepository] implementation, composed from the
/// current organization's feature repositories.
final reportsRepositoryProvider = Provider<ReportsRepository>(
  (ref) => AggregatingReportsRepository(
    production: ref.watch(productionRepositoryProvider),
    sales: ref.watch(salesRepositoryProvider),
    finance: ref.watch(financeRepositoryProvider),
    debts: ref.watch(debtsRepositoryProvider),
    inventory: ref.watch(inventoryRepositoryProvider),
    expenses: ref.watch(expensesRepositoryProvider),
  ),
);

/// The period currently shown. Defaults to today; the period control
/// switches it.
final selectedReportPeriodProvider = StateProvider<ReportPeriod>(
  (ref) => ReportPeriod.today(),
);

/// The full report for the selected period.
final reportSummaryProvider = FutureProvider<ReportSummary>((ref) {
  final period = ref.watch(selectedReportPeriodProvider);
  return ref.watch(reportsRepositoryProvider).fetchSummary(period);
});
