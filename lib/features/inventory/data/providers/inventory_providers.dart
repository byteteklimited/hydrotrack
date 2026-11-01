import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/action_controller.dart';
import '../../../offline/data/providers/offline_providers.dart';
import '../../../organizations/data/providers/organization_providers.dart';
import '../models/stock_forecast.dart';
import '../models/stock_item.dart';
import '../repositories/inventory_repository.dart';
import '../repositories/offline_inventory_repository.dart';
import '../repositories/stock_forecast_repository.dart';

/// The active [InventoryRepository] implementation.
final inventoryRepositoryProvider = Provider<InventoryRepository>((ref) {
  final remote = SupabaseInventoryRepository(
    ref.watch(currentTenantIdProvider),
  );
  final offline = ref.watch(offlineContextProvider);
  return offline == null ? remote : OfflineInventoryRepository(remote, offline);
});

/// All stock items, raw materials and finished goods together.
final stockItemsProvider = FutureProvider((ref) {
  return ref.watch(inventoryRepositoryProvider).fetchItems();
});

/// One item's movement ledger, newest first.
final itemMovementsProvider = FutureProvider.family((ref, String itemId) {
  return ref.watch(inventoryRepositoryProvider).fetchMovements(itemId);
});

/// One item's batches, oldest (FIFO order) first.
final itemBatchesProvider = FutureProvider.family((ref, String itemId) {
  return ref.watch(inventoryRepositoryProvider).fetchBatches(itemId);
});

/// Every batch, across every item, that still has stock left — what the
/// summary strip's expiring-soon count is computed from.
final activeBatchesProvider = FutureProvider((ref) {
  return ref.watch(inventoryRepositoryProvider).fetchActiveBatches();
});

/// When a physical recount was last performed, across the whole catalog.
final lastStockCountDateProvider = FutureProvider<DateTime?>((ref) {
  return ref.watch(inventoryRepositoryProvider).fetchLastStockCountDate();
});

/// Drives "Add stock" and "Adjust count": loading while the write is in
/// flight, error (most commonly no connection) if it fails — otherwise
/// refreshes the affected item and its movement history.
class StockActionController extends ActionController {
  StockActionController(this._ref);

  final Ref _ref;

  Future<void> addStock({
    required String itemId,
    required int quantity,
    String? note,
    DateTime? expiryDate,
  }) {
    return guard(() async {
      await _ref
          .read(inventoryRepositoryProvider)
          .addStock(
            itemId: itemId,
            quantity: quantity,
            note: note,
            expiryDate: expiryDate,
          );
      _refresh(itemId);
    });
  }

  Future<void> adjustCount({
    required String itemId,
    required int newCount,
    required String note,
  }) {
    return guard(() async {
      await _ref
          .read(inventoryRepositoryProvider)
          .adjustCount(itemId: itemId, newCount: newCount, note: note);
      _refresh(itemId);
      _ref.invalidate(lastStockCountDateProvider);
    });
  }

  Future<StockItem?> createItem({
    required String name,
    required String unit,
    required int reorderLevel,
  }) {
    return guard(() async {
      final created = await _ref
          .read(inventoryRepositoryProvider)
          .createItem(name: name, unit: unit, reorderLevel: reorderLevel);
      _ref.invalidate(stockItemsProvider);
      return created;
    });
  }

  Future<StockItem?> updateItemDetails({
    required String itemId,
    required String name,
    required String unit,
    required int reorderLevel,
  }) {
    return guard(() async {
      final updated = await _ref
          .read(inventoryRepositoryProvider)
          .updateItemDetails(
            itemId: itemId,
            name: name,
            unit: unit,
            reorderLevel: reorderLevel,
          );
      _ref.invalidate(stockItemsProvider);
      return updated;
    });
  }

  /// Returns `true` on success so the caller can tell a real failure
  /// apart from "nothing to check" — `guard` alone can't distinguish a
  /// failed `void` action from a successful one.
  Future<bool> deleteItem(String itemId) async {
    final result = await guard(() async {
      await _ref.read(inventoryRepositoryProvider).deleteItem(itemId);
      _ref.invalidate(stockItemsProvider);
      return true;
    });
    return result ?? false;
  }

  void _refresh(String itemId) {
    _ref.invalidate(stockItemsProvider);
    _ref.invalidate(itemMovementsProvider(itemId));
    _ref.invalidate(itemBatchesProvider(itemId));
    _ref.invalidate(activeBatchesProvider);
  }
}

final stockActionControllerProvider =
    StateNotifierProvider<StockActionController, AsyncValue<void>>(
      (ref) => StockActionController(ref),
    );

final stockForecastRepositoryProvider = Provider<StockForecastRepository>((
  ref,
) {
  final remote = SupabaseStockForecastRepository(
    ref.watch(currentTenantIdProvider),
  );
  final offline = ref.watch(offlineContextProvider);
  return offline == null
      ? remote
      : OfflineStockForecastRepository(remote, offline);
});

/// When each item runs out (item id → forecast); refreshed whenever stock
/// changes. Empty when it can't be loaded — the lists just don't show it.
final stockForecastProvider = FutureProvider<Map<String, StockForecast>>((
  ref,
) async {
  ref.watch(stockItemsProvider);
  try {
    return await ref.watch(stockForecastRepositoryProvider).fetchForecast();
  } catch (_) {
    return const {};
  }
});
