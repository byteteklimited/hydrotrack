import '../../../offline/data/models/outbox_operation.dart';
import '../../../offline/data/services/offline_context.dart';
import '../models/stock_batch.dart';
import '../models/stock_item.dart';
import '../models/stock_movement.dart';
import 'inventory_repository.dart';

/// Stock on a device set up for offline use: stock in and stock counts are
/// recorded on the device first; adding, renaming or deleting items needs
/// internet.
class OfflineInventoryRepository implements InventoryRepository {
  OfflineInventoryRepository(this._remote, this._offline);

  final InventoryRepository _remote;
  final OfflineContext _offline;

  @override
  Future<List<StockItem>> fetchItems() {
    return _offline.read(
      remote: _remote.fetchItems,
      local: (snapshot) =>
          snapshot.rows('stock_items').map(StockItem.fromJson).toList()
            ..sort((a, b) => a.name.compareTo(b.name)),
    );
  }

  @override
  Future<List<StockMovement>> fetchMovements(String itemId) {
    return _offline.read(
      remote: () => _remote.fetchMovements(itemId),
      local: (snapshot) =>
          snapshot
              .rows('stock_movements')
              .where((row) => row['item_id'] == itemId)
              .map(StockMovement.fromJson)
              .toList()
            ..sort((a, b) => b.at.compareTo(a.at)),
    );
  }

  @override
  Future<List<StockBatch>> fetchBatches(String itemId) {
    return _offline.read(
      remote: () => _remote.fetchBatches(itemId),
      local: (snapshot) => _batches(
        snapshot.rows('stock_batches').where((row) => row['item_id'] == itemId),
      ),
    );
  }

  @override
  Future<List<StockBatch>> fetchActiveBatches() {
    return _offline.read(
      remote: _remote.fetchActiveBatches,
      local: (snapshot) => _batches(
        snapshot
            .rows('stock_batches')
            .where((row) => (row['quantity_remaining'] as int) > 0),
      ),
    );
  }

  static List<StockBatch> _batches(Iterable<Map<String, dynamic>> rows) =>
      rows.map(StockBatch.fromJson).toList()
        ..sort((a, b) => a.receivedAt.compareTo(b.receivedAt));

  @override
  Future<DateTime?> fetchLastStockCountDate() {
    return _offline.read(
      remote: _remote.fetchLastStockCountDate,
      local: (snapshot) => snapshot.lastStockCountAt,
    );
  }

  @override
  Future<void> addStock({
    required String itemId,
    required int quantity,
    String? note,
    DateTime? expiryDate,
  }) async {
    await _offline.record(
      OperationType.stockIn,
      SupabaseInventoryRepository.addStockPayload(
        itemId: itemId,
        quantity: quantity,
        note: note,
        expiryDate: expiryDate,
      ),
    );
  }

  @override
  Future<void> adjustCount({
    required String itemId,
    required int newCount,
    required String note,
  }) async {
    await _offline.record(OperationType.stockCount, {
      'item_id': itemId,
      'new_count': newCount,
      'note': note,
    });
  }

  @override
  Future<StockItem> createItem({
    required String name,
    required String unit,
    required int reorderLevel,
  }) {
    return _offline.online(
      () => _remote.createItem(
        name: name,
        unit: unit,
        reorderLevel: reorderLevel,
      ),
    );
  }

  @override
  Future<StockItem> updateItemDetails({
    required String itemId,
    required String name,
    required String unit,
    required int reorderLevel,
  }) {
    return _offline.online(
      () => _remote.updateItemDetails(
        itemId: itemId,
        name: name,
        unit: unit,
        reorderLevel: reorderLevel,
      ),
    );
  }

  @override
  Future<void> deleteItem(String itemId) {
    return _offline.online(() => _remote.deleteItem(itemId));
  }
}
