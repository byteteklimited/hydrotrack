import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/action_controller.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../locations/data/providers/location_providers.dart';
import '../../../offline/data/providers/offline_providers.dart';
import '../../../production/data/models/production_run.dart';
import '../models/batch_trace.dart';
import '../models/permit.dart';
import '../models/sanitation.dart';
import '../models/water_test.dart';
import '../repositories/offline_quality_repository.dart';
import '../repositories/quality_repository.dart';

/// How many days of water tests and checklists the Quality screen shows.
const qualityHistoryDays = 14;

final qualityRepositoryProvider = Provider<QualityRepository>((ref) {
  final remote = SupabaseQualityRepository(
    ref.watch(dataScopeProvider).tenantId,
  );
  final offline = ref.watch(offlineContextProvider);
  return offline == null ? remote : OfflineQualityRepository(remote, offline);
});

DateTime _historyStart() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day - qualityHistoryDays + 1);
}

/// The last [qualityHistoryDays] days of water tests, newest first.
final waterTestsProvider = FutureProvider<List<WaterTest>>((ref) {
  return ref
      .watch(qualityRepositoryProvider)
      .fetchWaterTests(from: _historyStart(), to: nextDay(DateTime.now()));
});

final sanitationItemsProvider = FutureProvider<List<SanitationItem>>((ref) {
  return ref.watch(qualityRepositoryProvider).fetchSanitationItems();
});

/// The last [qualityHistoryDays] days of checklist ticks.
final sanitationChecksProvider = FutureProvider<List<SanitationCheck>>((ref) {
  return ref
      .watch(qualityRepositoryProvider)
      .fetchSanitationChecks(
        from: _historyStart(),
        to: nextDay(DateTime.now()),
      );
});

final permitsProvider = FutureProvider<List<Permit>>((ref) {
  return ref.watch(qualityRepositoryProvider).fetchPermits();
});

final batchTraceProvider = FutureProvider.autoDispose
    .family<BatchTrace, String>((ref, batchNumber) {
      return ref.watch(qualityRepositoryProvider).traceBatch(batchNumber);
    });

/// Record water test, fill in the checklist, and manage checklist items
/// and permits.
class QualityActionController extends ActionController {
  QualityActionController(this._ref);

  final Ref _ref;

  QualityRepository get _repository => _ref.read(qualityRepositoryProvider);

  Future<bool> _run(
    Future<void> Function() action,
    List<ProviderOrFamily> refresh,
  ) async {
    final done = await guard(() async {
      await action();
      for (final provider in refresh) {
        _ref.invalidate(provider);
      }
      return true;
    });
    return done ?? false;
  }

  Future<bool> recordWaterTest({
    required DateTime date,
    required ProductionShift shift,
    required num ph,
    required num tds,
    required num chlorine,
    String? note,
  }) => _run(
    () => _repository.recordWaterTest(
      date: date,
      shift: shift,
      ph: ph,
      tds: tds,
      chlorine: chlorine,
      note: note,
    ),
    [waterTestsProvider],
  );

  Future<bool> recordSanitationCheck(
    DateTime date,
    List<SanitationTick> ticks,
  ) => _run(() => _repository.recordSanitationCheck(date, ticks), [
    sanitationChecksProvider,
  ]);

  Future<bool> addSanitationItem(String name, int position) => _run(
    () => _repository.addSanitationItem(name, position),
    [sanitationItemsProvider],
  );

  Future<bool> updateSanitationItem(
    String id, {
    String? name,
    bool? isActive,
  }) => _run(
    () => _repository.updateSanitationItem(id, name: name, isActive: isActive),
    [sanitationItemsProvider],
  );

  Future<bool> savePermit(Permit permit, {String? id}) =>
      _run(() => _repository.savePermit(permit, id: id), [permitsProvider]);

  Future<bool> deletePermit(String id) =>
      _run(() => _repository.deletePermit(id), [permitsProvider]);
}

final qualityActionControllerProvider =
    StateNotifierProvider.autoDispose<
      QualityActionController,
      AsyncValue<void>
    >((ref) => QualityActionController(ref));
