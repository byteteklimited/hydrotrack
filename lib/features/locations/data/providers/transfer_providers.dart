import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/action_controller.dart';
import '../../../inventory/data/providers/inventory_providers.dart';
import '../../../offline/data/providers/offline_providers.dart';
import '../models/stock_transfer.dart';
import '../repositories/transfers_repository.dart';
import 'location_providers.dart';

final transfersRepositoryProvider = Provider<TransfersRepository>((ref) {
  final remote = SupabaseTransfersRepository(
    ref.watch(dataScopeProvider).tenantId,
  );
  final offline = ref.watch(offlineContextProvider);
  return offline == null ? remote : OfflineTransfersRepository(remote, offline);
});

final transfersProvider = FutureProvider.autoDispose<List<StockTransfer>>((
  ref,
) {
  return ref.watch(transfersRepositoryProvider).fetchTransfers();
});

class TransfersActionController extends ActionController {
  TransfersActionController(this._ref);

  final Ref _ref;

  Future<bool> _run(Future<void> Function() action) async {
    final done = await guard(() async {
      await action();
      _ref
        ..invalidate(transfersProvider)
        ..invalidate(stockItemsProvider);
      return true;
    });
    return done ?? false;
  }

  Future<bool> send({
    required String toLocationId,
    required Map<String, int> quantities,
    String? note,
  }) => _run(
    () => _ref
        .read(transfersRepositoryProvider)
        .send(toLocationId: toLocationId, quantities: quantities, note: note),
  );

  Future<bool> receive(String transferId) =>
      _run(() => _ref.read(transfersRepositoryProvider).receive(transferId));
}

final transfersActionControllerProvider =
    StateNotifierProvider.autoDispose<
      TransfersActionController,
      AsyncValue<void>
    >((ref) => TransfersActionController(ref));
