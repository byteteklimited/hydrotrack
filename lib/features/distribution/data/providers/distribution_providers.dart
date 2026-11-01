import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/payment_channel.dart';
import '../../../../core/utils/action_controller.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../inventory/data/providers/inventory_providers.dart';
import '../../../offline/data/providers/offline_providers.dart';
import '../../../organizations/data/providers/organization_providers.dart';
import '../../../sales/data/models/sale.dart';
import '../../../sales/data/providers/sales_providers.dart';
import '../models/driver.dart';
import '../models/load_out.dart';
import '../models/vehicle.dart';
import '../repositories/distribution_repository.dart';
import '../repositories/offline_distribution_repository.dart';

/// The active [DistributionRepository] implementation.
final distributionRepositoryProvider = Provider<DistributionRepository>((ref) {
  final remote = SupabaseDistributionRepository(
    ref.watch(currentTenantIdProvider),
  );
  final offline = ref.watch(offlineContextProvider);
  return offline == null
      ? remote
      : OfflineDistributionRepository(remote, offline);
});

final driversProvider = FutureProvider<List<Driver>>((ref) {
  return ref.watch(distributionRepositoryProvider).fetchDrivers();
});

final vehiclesProvider = FutureProvider<List<Vehicle>>((ref) {
  return ref.watch(distributionRepositoryProvider).fetchVehicles();
});

/// How many days back the trip list shows ("Show earlier" adds more).
final loadOutHistoryDaysProvider = StateProvider<int>(
  (ref) => HistoryWindow.initialDays,
);

/// Trips still on the road plus those in the history window, most recent
/// first.
final loadOutsProvider = FutureProvider<List<LoadOut>>((ref) {
  final days = ref.watch(loadOutHistoryDaysProvider);
  return ref
      .watch(distributionRepositoryProvider)
      .fetchLoadOuts(from: HistoryWindow.since(days));
});

/// Drives "New load-out", "Settle trip", "Add driver", and "Add
/// vehicle": loading while the write is in flight, error (most commonly
/// no connection) if it fails — otherwise refreshes the trip list.
class DistributionActionController extends ActionController {
  DistributionActionController(this._ref);

  final Ref _ref;

  Future<void> recordLoadOut(LoadOut loadOut) {
    return guard(() async {
      await _ref.read(distributionRepositoryProvider).recordLoadOut(loadOut);
      _ref.invalidate(loadOutsProvider);
    });
  }

  Future<Driver?> createDriver({required String name, required String phone}) {
    return guard(() async {
      final created = await _ref
          .read(distributionRepositoryProvider)
          .createDriver(name: name, phone: phone);
      _ref.invalidate(driversProvider);
      return created;
    });
  }

  Future<Vehicle?> createVehicle({required String name}) {
    return guard(() async {
      final created = await _ref
          .read(distributionRepositoryProvider)
          .createVehicle(name: name);
      _ref.invalidate(vehiclesProvider);
      return created;
    });
  }

  Future<void> settleTrip({
    required String loadOutId,
    required int bagsSold,
    required int bagsReturned,
    required int bagsDamaged,
    required num cashReturned,
    String? discrepancyNote,
    CustomerType customerType = CustomerType.walkIn,
    String? customerName,
    num? unitPrice,
    num? amountPaid,
    PaymentMethod paymentMethod = PaymentMethod.cash,
    PaymentChannel? paidChannel,
  }) {
    return guard(() async {
      await _ref
          .read(distributionRepositoryProvider)
          .settleTrip(
            loadOutId: loadOutId,
            bagsSold: bagsSold,
            bagsReturned: bagsReturned,
            bagsDamaged: bagsDamaged,
            cashReturned: cashReturned,
            discrepancyNote: discrepancyNote,
            customerType: customerType,
            customerName: customerName,
            unitPrice: unitPrice,
            amountPaid: amountPaid,
            paymentMethod: paymentMethod,
            paidChannel: paidChannel,
          );
      _ref.invalidate(loadOutsProvider);
      // Settling can move stock (bags returned) and, when a unit price
      // is given, create a real sale — invalidate everything either one
      // could affect, closing the stock-staleness gap load-outs never
      // closed even before this, not just the new sale-related one.
      _ref.invalidate(stockItemsProvider);
      _ref.invalidate(activeBatchesProvider);
      if (unitPrice != null) {
        _ref.invalidate(salesProvider);
      }
    });
  }
}

final distributionActionControllerProvider =
    StateNotifierProvider<DistributionActionController, AsyncValue<void>>(
      (ref) => DistributionActionController(ref),
    );
