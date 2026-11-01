import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/action_controller.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../offline/data/providers/offline_providers.dart';
import '../../../organizations/data/providers/organization_providers.dart';
import '../models/cash_count.dart';
import '../repositories/cash_count_repository.dart';
import 'finance_providers.dart';

final cashCountRepositoryProvider = Provider<CashCountRepository>((ref) {
  final remote = SupabaseCashCountRepository(
    ref.watch(currentTenantIdProvider),
  );
  final offline = ref.watch(offlineContextProvider);
  return offline == null ? remote : OfflineCashCountRepository(remote, offline);
});

/// The signed-in person's expected cash, fresh each time it's opened.
final myExpectedCashProvider = FutureProvider.autoDispose<ExpectedCash>((ref) {
  return ref.watch(cashCountRepositoryProvider).fetchMyExpected();
});

/// Today's counts, newest first (cashiers: their own).
final todaysCashCountsProvider = FutureProvider<List<CashCount>>((ref) {
  return ref
      .watch(cashCountRepositoryProvider)
      .fetchCounts(from: dateOnly(DateTime.now()));
});

class CashCountController extends ActionController {
  CashCountController(this._ref);

  final Ref _ref;

  Future<bool> record({required num counted, String? note}) => _run(
    () => _ref
        .read(cashCountRepositoryProvider)
        .recordCount(counted: counted, note: note),
  );

  Future<bool> confirm(String countId) =>
      _run(() => _ref.read(cashCountRepositoryProvider).confirm(countId));

  Future<bool> _run(Future<void> Function() action) async {
    final done = await guard(() async {
      await action();
      _ref.invalidate(todaysCashCountsProvider);
      _ref.invalidate(myExpectedCashProvider);
      _ref.invalidate(cashEntriesProvider);
      _ref.invalidate(openSyncFlagsProvider);
      return true;
    });
    return done ?? false;
  }
}

final cashCountControllerProvider =
    StateNotifierProvider.autoDispose<CashCountController, AsyncValue<void>>(
      (ref) => CashCountController(ref),
    );
