import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/payment_channel.dart';
import '../../../../core/utils/action_controller.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../finance/data/providers/finance_providers.dart';
import '../../../inventory/data/providers/inventory_providers.dart';
import '../../../locations/data/providers/location_providers.dart';
import '../../../offline/data/providers/offline_providers.dart';
import '../models/purchase.dart';
import '../models/supplier.dart';
import '../repositories/purchases_repository.dart';

final purchasesRepositoryProvider = Provider<PurchasesRepository>((ref) {
  final remote = SupabasePurchasesRepository(
    ref.watch(dataScopeProvider).tenantId,
  );
  final offline = ref.watch(offlineContextProvider);
  return offline == null ? remote : OfflinePurchasesRepository(remote, offline);
});

final suppliersProvider = FutureProvider<List<Supplier>>((ref) {
  return ref.watch(purchasesRepositoryProvider).fetchSuppliers();
});

final supplierLedgerProvider =
    FutureProvider.family<List<SupplierLedgerEntry>, String>((ref, supplierId) {
      return ref
          .watch(purchasesRepositoryProvider)
          .fetchSupplierLedger(supplierId);
    });

/// How many days back the purchase list shows ("Show earlier" adds more).
final purchaseHistoryDaysProvider = StateProvider<int>(
  (ref) => HistoryWindow.initialDays,
);

final purchasesProvider = FutureProvider<List<Purchase>>((ref) {
  final days = ref.watch(purchaseHistoryDaysProvider);
  return ref
      .watch(purchasesRepositoryProvider)
      .fetchPurchases(from: HistoryWindow.since(days));
});

class PurchaseActionController extends ActionController {
  PurchaseActionController(this._ref);

  final Ref _ref;

  PurchasesRepository get _repository => _ref.read(purchasesRepositoryProvider);

  Future<Supplier?> createSupplier({required String name, String? phone}) {
    return guard(() async {
      final supplier = await _repository.createSupplier(
        name: name,
        phone: phone,
      );
      _ref.invalidate(suppliersProvider);
      return supplier;
    });
  }

  Future<bool> recordPurchase({
    required String supplierId,
    required DateTime date,
    required List<PurchaseLine> lines,
    required num amountPaid,
    PaymentChannel? paidChannel,
    String? note,
  }) => _run(
    () => _repository.recordPurchase(
      supplierId: supplierId,
      date: date,
      lines: lines,
      amountPaid: amountPaid,
      paidChannel: paidChannel,
      note: note,
    ),
  );

  Future<bool> paySupplier({
    required String supplierId,
    required num amount,
    required PaymentChannel channel,
    required DateTime date,
    String? note,
  }) => _run(
    () => _repository.paySupplier(
      supplierId: supplierId,
      amount: amount,
      channel: channel,
      date: date,
      note: note,
    ),
  );

  Future<bool> _run(Future<void> Function() action) async {
    final done = await guard(() async {
      await action();
      _ref.invalidate(suppliersProvider);
      _ref.invalidate(supplierLedgerProvider);
      _ref.invalidate(purchasesProvider);
      _ref.invalidate(stockItemsProvider);
      _ref.invalidate(cashEntriesProvider);
      _ref.invalidate(financePositionProvider);
      return true;
    });
    return done ?? false;
  }
}

final purchaseActionControllerProvider =
    StateNotifierProvider.autoDispose<
      PurchaseActionController,
      AsyncValue<void>
    >((ref) => PurchaseActionController(ref));
