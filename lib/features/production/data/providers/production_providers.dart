import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/action_controller.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../inventory/data/providers/inventory_providers.dart';
import '../../../locations/data/providers/location_providers.dart';
import '../../../offline/data/providers/offline_providers.dart';
import '../models/production_run.dart';
import '../repositories/offline_production_repository.dart';
import '../repositories/production_repository.dart';

/// The active [ProductionRepository] implementation.
final productionRepositoryProvider = Provider<ProductionRepository>((ref) {
  final remote = SupabaseProductionRepository(
    ref.watch(dataScopeProvider).tenantId,
  );
  final offline = ref.watch(offlineContextProvider);
  return offline == null
      ? remote
      : OfflineProductionRepository(remote, offline);
});

/// How many days back the production list shows ("Show earlier" adds
/// more).
final productionHistoryDaysProvider = StateProvider<int>(
  (ref) => HistoryWindow.initialDays,
);

/// Production runs in the history window, most recent first.
final productionRunsProvider = FutureProvider<List<ProductionRun>>((ref) {
  final days = ref.watch(productionHistoryDaysProvider);
  return ref
      .watch(productionRepositoryProvider)
      .fetchRuns(from: HistoryWindow.since(days));
});

/// Today's bags produced, bags wasted, and wastage as a percentage of
/// today's total output.
class ProductionTotals {
  const ProductionTotals({
    required this.bagsProducedToday,
    required this.wastageToday,
    required this.wastagePercentToday,
  });

  final int bagsProducedToday;
  final int wastageToday;
  final double wastagePercentToday;
}

final todaysProductionTotalsProvider = Provider<AsyncValue<ProductionTotals>>((
  ref,
) {
  final runsAsync = ref.watch(productionRunsProvider);
  return runsAsync.whenData((runs) {
    final today = DateTime.now();
    final todaysRuns = runs.where((run) => isSameDay(run.date, today));
    final bags = todaysRuns.fold<int>(
      0,
      (sum, run) => sum + run.quantityProduced,
    );
    final wastage = todaysRuns.fold<int>(0, (sum, run) => sum + run.wastage);
    final total = bags + wastage;
    final percent = total == 0 ? 0.0 : (wastage / total) * 100;
    return ProductionTotals(
      bagsProducedToday: bags,
      wastageToday: wastage,
      wastagePercentToday: percent,
    );
  });
});

/// Drives the "Record production" form — same controller for adding a
/// new run and editing an existing one: loading while the save is in
/// flight, error (most commonly no connection) if it fails.
class RecordProductionController extends ActionController {
  RecordProductionController(this._ref);

  final Ref _ref;

  Future<ProductionRun?> record(ProductionRun run, {DateTime? expiryDate}) {
    return guard(() async {
      final saved = await _ref
          .read(productionRepositoryProvider)
          .recordRun(run, expiryDate: expiryDate);
      _ref.invalidate(productionRunsProvider);
      // A run now deducts raw materials per its recipe, if one exists
      // (supabase/migrations/0006_business_rpcs.sql), and creates a finished-goods batch for its
      // output (supabase/migrations/0006_business_rpcs.sql) — invalidate so Inventory doesn't keep
      // showing stale quantities.
      _ref.invalidate(stockItemsProvider);
      _ref.invalidate(activeBatchesProvider);
      return saved;
    });
  }

  Future<ProductionRun?> update(ProductionRun run, {DateTime? expiryDate}) {
    return guard(() async {
      final saved = await _ref
          .read(productionRepositoryProvider)
          .updateRun(run, expiryDate: expiryDate);
      _ref.invalidate(productionRunsProvider);
      _ref.invalidate(stockItemsProvider);
      _ref.invalidate(activeBatchesProvider);
      return saved;
    });
  }

  /// Returns `true` on success so the caller can tell a real failure
  /// apart from "nothing to check" — `guard` alone can't distinguish a
  /// failed `void` action from a successful one.
  Future<bool> delete(String runId) async {
    final result = await guard(() async {
      await _ref.read(productionRepositoryProvider).deleteRun(runId);
      _ref.invalidate(productionRunsProvider);
      _ref.invalidate(stockItemsProvider);
      _ref.invalidate(activeBatchesProvider);
      return true;
    });
    return result ?? false;
  }
}

final recordProductionControllerProvider =
    StateNotifierProvider<RecordProductionController, AsyncValue<void>>(
      (ref) => RecordProductionController(ref),
    );
