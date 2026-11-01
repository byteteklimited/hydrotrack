import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../offline/data/services/offline_context.dart';
import '../models/stock_forecast.dart';

/// When each item will run out (item id → forecast).
abstract class StockForecastRepository {
  Future<Map<String, StockForecast>> fetchForecast();
}

class SupabaseStockForecastRepository implements StockForecastRepository {
  SupabaseStockForecastRepository(this._tenantId);

  final String _tenantId;

  @override
  Future<Map<String, StockForecast>> fetchForecast() async {
    final rows = await Supabase.instance.client.rpc(
      'stock_forecast',
      params: {'p_tenant_id': _tenantId},
    );
    return {
      for (final row in rows as List)
        (row as Map)['item_id'] as String: StockForecast.fromJson(
          Map<String, dynamic>.from(row),
        ),
    };
  }
}

/// Offline, worked out from the stock movements on the device.
class OfflineStockForecastRepository implements StockForecastRepository {
  OfflineStockForecastRepository(this._remote, this._offline);

  final StockForecastRepository _remote;
  final OfflineContext _offline;

  @override
  Future<Map<String, StockForecast>> fetchForecast() => _offline.read(
    remote: _remote.fetchForecast,
    local: (snapshot) => StockForecast.compute(
      items: snapshot.rows('stock_items'),
      movements: snapshot.rows('stock_movements'),
      now: DateTime.now(),
    ),
  );
}
