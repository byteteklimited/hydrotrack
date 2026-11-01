import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/payment_channel.dart';
import '../../../../core/utils/action_controller.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../inventory/data/providers/inventory_providers.dart';
import '../../../offline/data/providers/offline_providers.dart';
import '../../../organizations/data/providers/organization_providers.dart';
import '../models/sale.dart';
import '../repositories/offline_sales_repository.dart';
import '../repositories/sales_repository.dart';

/// The active [SalesRepository] implementation.
final salesRepositoryProvider = Provider<SalesRepository>((ref) {
  final remote = SupabaseSalesRepository(ref.watch(currentTenantIdProvider));
  final offline = ref.watch(offlineContextProvider);
  return offline == null ? remote : OfflineSalesRepository(remote, offline);
});

/// All sales, most recent first.
final salesProvider = FutureProvider<List<Sale>>((ref) {
  return ref.watch(salesRepositoryProvider).fetchSales();
});

/// Distributor directory (from Debts' `customers` table) for the
/// "record sale" customer picker.
final distributorNamesProvider = FutureProvider<List<String>>((ref) {
  return ref.watch(salesRepositoryProvider).fetchDistributorNames();
});

/// The day currently shown in the sales list. Defaults to today; the day
/// switcher moves it backward/forward.
final selectedSalesDayProvider = StateProvider<DateTime>(
  (ref) => dateOnly(DateTime.now()),
);

/// Sales for [selectedSalesDayProvider], most recent first.
final salesForSelectedDayProvider = Provider<AsyncValue<List<Sale>>>((ref) {
  final day = ref.watch(selectedSalesDayProvider);
  return ref
      .watch(salesProvider)
      .whenData(
        (sales) =>
            sales.where((sale) => isSameDay(sale.dateTime, day)).toList(),
      );
});

/// Today's takings: cash and transfer taken in full, plus total bags sold
/// regardless of payment method.
class SalesTotals {
  const SalesTotals({
    required this.cashToday,
    required this.transferToday,
    required this.bagsSoldToday,
  });

  final num cashToday;
  final num transferToday;
  final int bagsSoldToday;
}

final todaysSalesTotalsProvider = Provider<AsyncValue<SalesTotals>>((ref) {
  final today = DateTime.now();
  return ref.watch(salesProvider).whenData((sales) {
    final todaysSales = sales.where(
      (sale) => isSameDay(sale.dateTime, today) && !sale.isVoided,
    );
    num cash = 0;
    num transfer = 0;
    var bags = 0;
    for (final sale in todaysSales) {
      bags += sale.totalBags;
      if (sale.paymentMethod == PaymentMethod.cash) cash += sale.amountPaid;
      if (sale.paymentMethod == PaymentMethod.transfer) {
        transfer += sale.amountPaid;
      }
    }
    return SalesTotals(
      cashToday: cash,
      transferToday: transfer,
      bagsSoldToday: bags,
    );
  });
});

/// Drives the "Record sale" form: loading while the save is in flight,
/// error (most commonly no connection) if it fails.
class RecordSaleController extends ActionController {
  RecordSaleController(this._ref);

  final Ref _ref;

  Future<Sale?> record(Sale sale, {PaymentChannel? paidChannel}) {
    return guard(() async {
      final saved = await _ref
          .read(salesRepositoryProvider)
          .recordSale(sale, paidChannel: paidChannel);
      _ref.invalidate(salesProvider);
      // A sale now deducts the matching finished-goods item server-side
      // (supabase/migrations/0006_business_rpcs.sql) — invalidate so Inventory doesn't keep showing
      // the pre-sale quantity until something else happens to refetch it.
      _ref.invalidate(stockItemsProvider);
      _ref.invalidate(activeBatchesProvider);
      return saved;
    });
  }
}

final recordSaleControllerProvider =
    StateNotifierProvider<RecordSaleController, AsyncValue<void>>(
      (ref) => RecordSaleController(ref),
    );

/// Drives voiding a sale: loading while the reversal is in flight, error
/// if it fails (the RPC's own rejection message — "already voided",
/// "a reason is required" — not a generic one, since both are real
/// answers the user needs to read).
class VoidSaleController extends ActionController {
  VoidSaleController(this._ref);

  final Ref _ref;

  Future<void> voidSale({required String saleId, required String reason}) {
    return guard(() async {
      await _ref
          .read(salesRepositoryProvider)
          .voidSale(saleId: saleId, reason: reason);
      _ref.invalidate(salesProvider);
      // Stock comes back on a void — same staleness fix every other
      // stock-affecting action here already applies.
      _ref.invalidate(stockItemsProvider);
      _ref.invalidate(activeBatchesProvider);
    });
  }
}

final voidSaleControllerProvider =
    StateNotifierProvider<VoidSaleController, AsyncValue<void>>(
      (ref) => VoidSaleController(ref),
    );
