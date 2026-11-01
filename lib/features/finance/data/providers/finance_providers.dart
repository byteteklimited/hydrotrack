import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/action_controller.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../offline/data/providers/offline_providers.dart';
import '../../../organizations/data/providers/organization_providers.dart';
import '../models/cash_entry.dart';
import '../models/finance_position.dart';
import '../repositories/finance_repository.dart';
import '../repositories/offline_finance_repository.dart';

/// The active [FinanceRepository] implementation.
final financeRepositoryProvider = Provider<FinanceRepository>((ref) {
  final remote = SupabaseFinanceRepository(ref.watch(currentTenantIdProvider));
  final offline = ref.watch(offlineContextProvider);
  return offline == null ? remote : OfflineFinanceRepository(remote, offline);
});

/// Cash entries on the selected day plus today's (for today's totals),
/// most recent first. Only those days are loaded.
final cashEntriesProvider = FutureProvider<List<CashEntry>>((ref) async {
  final repository = ref.watch(financeRepositoryProvider);
  final days = {
    ref.watch(selectedFinanceDayProvider),
    dateOnly(DateTime.now()),
  };
  final perDay = await Future.wait([
    for (final day in days)
      repository.fetchEntries(from: day, to: nextDay(day)),
  ]);
  return perDay.expand((entries) => entries).toList()
    ..sort((a, b) => b.dateTime.compareTo(a.dateTime));
});

/// Running cash-in-hand and bank balance.
final financePositionProvider = FutureProvider<FinancePosition>((ref) {
  return ref.watch(financeRepositoryProvider).fetchPosition();
});

/// The day currently shown in the ledger. Defaults to today; the day
/// switcher moves it backward/forward.
final selectedFinanceDayProvider = StateProvider<DateTime>(
  (ref) => dateOnly(DateTime.now()),
);

/// Which entries the filter chips show.
enum FinanceFilter { all, moneyIn, moneyOut }

final financeFilterProvider = StateProvider<FinanceFilter>(
  (ref) => FinanceFilter.all,
);

/// Entries for the selected day, filtered by direction if a chip other
/// than "All" is active.
final filteredEntriesProvider = Provider<AsyncValue<List<CashEntry>>>((ref) {
  final day = ref.watch(selectedFinanceDayProvider);
  final filter = ref.watch(financeFilterProvider);
  return ref.watch(cashEntriesProvider).whenData((entries) {
    return entries.where((entry) {
      if (!isSameDay(entry.dateTime, day)) return false;
      return switch (filter) {
        FinanceFilter.all => true,
        FinanceFilter.moneyIn => entry.direction == CashDirection.moneyIn,
        FinanceFilter.moneyOut => entry.direction == CashDirection.moneyOut,
      };
    }).toList();
  });
});

/// Today's money in and money out, regardless of which day the ledger
/// below is showing.
class FinanceTodayTotals {
  const FinanceTodayTotals({
    required this.moneyInToday,
    required this.moneyOutToday,
  });

  final num moneyInToday;
  final num moneyOutToday;
}

final financeTodayTotalsProvider = Provider<AsyncValue<FinanceTodayTotals>>((
  ref,
) {
  final today = DateTime.now();
  return ref.watch(cashEntriesProvider).whenData((entries) {
    final todaysEntries = entries.where(
      (entry) => isSameDay(entry.dateTime, today),
    );
    num moneyIn = 0;
    num moneyOut = 0;
    for (final entry in todaysEntries) {
      if (entry.direction == CashDirection.moneyIn) {
        moneyIn += entry.amount;
      } else {
        moneyOut += entry.amount;
      }
    }
    return FinanceTodayTotals(moneyInToday: moneyIn, moneyOutToday: moneyOut);
  });
});

/// Drives "Record entry": loading while the mock save is in flight.
class RecordCashEntryController extends ActionController {
  RecordCashEntryController(this._ref);

  final Ref _ref;

  Future<void> record(CashEntry entry) {
    return guard(() async {
      await _ref.read(financeRepositoryProvider).recordEntry(entry);
      _ref.invalidate(cashEntriesProvider);
      _ref.invalidate(financePositionProvider);
    });
  }
}

final recordCashEntryControllerProvider =
    StateNotifierProvider<RecordCashEntryController, AsyncValue<void>>(
      (ref) => RecordCashEntryController(ref),
    );
