import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/utils/rpc_params.dart';
import '../models/stock_batch.dart';
import '../models/stock_item.dart';
import '../models/stock_movement.dart';

/// Contract for reading stock levels and recording movements against them.
///
/// Phase 3 hook: when a production run is recorded, this repository should
/// auto-create a [MovementType.productionUse] movement and decrement the
/// matching raw-material items (nylon rolls, preforms, caps, chemicals per
/// bag/bottle produced). That cross-feature wiring is intentionally not
/// built yet — Production and Inventory stay independent.
abstract class InventoryRepository {
  Future<List<StockItem>> fetchItems();
  Future<List<StockMovement>> fetchMovements(String itemId);

  /// One item's batches, oldest-received first — the order stock is
  /// actually drawn from.
  Future<List<StockBatch>> fetchBatches(String itemId);

  /// Every batch, across every item, that still has stock left in it —
  /// what the expiring-soon count on the summary strip is computed from.
  /// Depleted batches are excluded; an empty batch expiring tomorrow
  /// isn't a risk to anything.
  Future<List<StockBatch>> fetchActiveBatches();

  Future<void> addStock({
    required String itemId,
    required int quantity,
    String? note,
    DateTime? expiryDate,
  });
  Future<void> adjustCount({
    required String itemId,
    required int newCount,
    required String note,
  });

  /// Adds a raw material. Admin/Manager only (enforced by RLS). Always
  /// starts at zero — no fabricated stock history. Finished goods come
  /// with their product (Products).
  Future<StockItem> createItem({
    required String name,
    required String unit,
    required int reorderLevel,
  });

  /// Corrects a catalog entry's name/unit/reorder level. Admin/Manager
  /// only (enforced server-side) — category and the product-type link
  /// are fixed at creation, not editable here.
  Future<StockItem> updateItemDetails({
    required String itemId,
    required String name,
    required String unit,
    required int reorderLevel,
  });

  /// Removes an item from the catalog. Admin/Manager only. Fails
  /// server-side if the item has any stock-movement history, to avoid
  /// silently deleting that audit trail via cascade.
  Future<void> deleteItem(String itemId);

  /// When a physical recount was last performed, across every item —
  /// null if one never has been. Specifically the most recent
  /// [MovementType.adjustment], not just any movement, since "last stock
  /// count" means a recount, not a delivery.
  Future<DateTime?> fetchLastStockCountDate();
}

/// Backed by `stock_items` and `stock_movements`. `addStock`/`adjustCount`
/// call Postgres functions (`add_stock`/`adjust_stock_count`) so the
/// quantity update and the movement log entry commit together — see
/// supabase/migrations/0006_business_rpcs.sql. `by_whom` comes from the authenticated session, not
/// from the caller, so it's always accurate.
class SupabaseInventoryRepository implements InventoryRepository {
  SupabaseInventoryRepository(this._tenantId);

  /// Every query and write is scoped to this organization.
  final String _tenantId;

  SupabaseClient get _client => Supabase.instance.client;

  static const _selectWithRecorder = '*, profiles!by_whom(full_name)';
  static const _selectItem = '*, products(name, unit)';

  @override
  Future<List<StockItem>> fetchItems() async {
    final rows = await _client
        .from('stock_items')
        .select(_selectItem)
        .eq('tenant_id', _tenantId)
        .order('name');
    return (rows as List)
        .map((row) => StockItem.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<List<StockMovement>> fetchMovements(String itemId) async {
    final rows = await _client
        .from('stock_movements')
        .select(_selectWithRecorder)
        .eq('tenant_id', _tenantId)
        .eq('item_id', itemId)
        .order('at', ascending: false);
    return (rows as List)
        .map((row) => StockMovement.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<List<StockBatch>> fetchBatches(String itemId) async {
    final rows = await _client
        .from('stock_batches')
        .select()
        .eq('tenant_id', _tenantId)
        .eq('item_id', itemId)
        .order('received_at');
    return (rows as List)
        .map((row) => StockBatch.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<List<StockBatch>> fetchActiveBatches() async {
    final rows = await _client
        .from('stock_batches')
        .select()
        .eq('tenant_id', _tenantId)
        .gt('quantity_remaining', 0)
        .order('received_at');
    return (rows as List)
        .map((row) => StockBatch.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<void> addStock({
    required String itemId,
    required int quantity,
    String? note,
    DateTime? expiryDate,
  }) {
    return _client.rpc(
      'add_stock',
      params: rpcParams(
        _tenantId,
        addStockPayload(
          itemId: itemId,
          quantity: quantity,
          note: note,
          expiryDate: expiryDate,
        ),
      ),
    );
  }

  /// add_stock's values (without the `p_` prefix), shared with offline
  /// mode.
  static Map<String, dynamic> addStockPayload({
    required String itemId,
    required int quantity,
    String? note,
    DateTime? expiryDate,
  }) => {
    'item_id': itemId,
    'quantity': quantity,
    'note': note,
    'expiry_date': expiryDate == null ? null : dateParam(expiryDate),
  };

  @override
  Future<void> adjustCount({
    required String itemId,
    required int newCount,
    required String note,
  }) {
    return _client.rpc(
      'adjust_stock_count',
      params: rpcParams(_tenantId, {
        'item_id': itemId,
        'new_count': newCount,
        'note': note,
      }),
    );
  }

  @override
  Future<StockItem> createItem({
    required String name,
    required String unit,
    required int reorderLevel,
  }) async {
    final row = await _client
        .from('stock_items')
        .insert({
          'tenant_id': _tenantId,
          'name': name,
          'category': stockCategoryToDb(StockCategory.rawMaterial),
          'unit': unit,
          'quantity_on_hand': 0,
          'reorder_level': reorderLevel,
        })
        .select(_selectItem)
        .single();
    return StockItem.fromJson(row);
  }

  @override
  Future<StockItem> updateItemDetails({
    required String itemId,
    required String name,
    required String unit,
    required int reorderLevel,
  }) async {
    final row = await _client.rpc(
      'update_stock_item_details',
      params: {
        'p_tenant_id': _tenantId,
        'p_item_id': itemId,
        'p_name': name,
        'p_unit': unit,
        'p_reorder_level': reorderLevel,
      },
    );
    return StockItem.fromJson(row as Map<String, dynamic>);
  }

  @override
  Future<void> deleteItem(String itemId) {
    return _client.rpc(
      'delete_stock_item',
      params: {'p_tenant_id': _tenantId, 'p_item_id': itemId},
    );
  }

  @override
  Future<DateTime?> fetchLastStockCountDate() async {
    final rows = await _client
        .from('stock_movements')
        .select('at')
        .eq('tenant_id', _tenantId)
        .eq('type', 'adjustment')
        .order('at', ascending: false)
        .limit(1);
    final list = rows as List;
    if (list.isEmpty) return null;
    return DateTime.parse((list.first as Map<String, dynamic>)['at'] as String);
  }
}
