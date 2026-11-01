import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../debts/data/providers/debts_providers.dart';
import '../../../distribution/data/providers/distribution_providers.dart';
import '../../../finance/data/providers/finance_providers.dart';
import '../../../inventory/data/providers/inventory_providers.dart';
import '../../../production/data/providers/production_providers.dart';
import '../../../sales/data/providers/sales_providers.dart';
import '../models/dashboard_snapshot.dart';
import '../repositories/dashboard_repository.dart';

/// The active [DashboardRepository] implementation, composed from the
/// current organization's feature repositories.
final dashboardRepositoryProvider = Provider<DashboardRepository>(
  (ref) => AggregatingDashboardRepository(
    production: ref.watch(productionRepositoryProvider),
    finance: ref.watch(financeRepositoryProvider),
    debts: ref.watch(debtsRepositoryProvider),
    inventory: ref.watch(inventoryRepositoryProvider),
    sales: ref.watch(salesRepositoryProvider),
    distribution: ref.watch(distributionRepositoryProvider),
  ),
);

/// Today's report-at-a-glance, fetched once per app session.
final dashboardSnapshotProvider = FutureProvider<DashboardSnapshot>((ref) {
  return ref.watch(dashboardRepositoryProvider).fetchToday();
});
