import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../offline/data/services/offline_context.dart';
import '../models/stock_transfer.dart';

/// Stock moving between locations. Needs internet.
abstract class TransfersRepository {
  Future<List<StockTransfer>> fetchTransfers();

  /// Sends item id → quantity from the current location.
  Future<void> send({
    required String toLocationId,
    required Map<String, int> quantities,
    String? note,
  });
  Future<void> receive(String transferId);
}

class SupabaseTransfersRepository implements TransfersRepository {
  SupabaseTransfersRepository(this._tenantId);

  final String _tenantId;

  SupabaseClient get _client => Supabase.instance.client;

  @override
  Future<List<StockTransfer>> fetchTransfers() async {
    final rows = await _client.rpc(
      'location_transfers',
      params: {'p_tenant_id': _tenantId},
    );
    return [
      for (final row in rows as List)
        StockTransfer.fromJson(row as Map<String, dynamic>),
    ];
  }

  @override
  Future<void> send({
    required String toLocationId,
    required Map<String, int> quantities,
    String? note,
  }) => _client.rpc(
    'send_transfer',
    params: {
      'p_tenant_id': _tenantId,
      'p_to_location_id': toLocationId,
      'p_lines': [
        for (final entry in quantities.entries)
          {'item_id': entry.key, 'quantity': entry.value},
      ],
      'p_note': note,
    },
  );

  @override
  Future<void> receive(String transferId) => _client.rpc(
    'receive_transfer',
    params: {'p_tenant_id': _tenantId, 'p_transfer_id': transferId},
  );
}

class OfflineTransfersRepository implements TransfersRepository {
  OfflineTransfersRepository(this._remote, this._offline);

  final TransfersRepository _remote;
  final OfflineContext _offline;

  @override
  Future<List<StockTransfer>> fetchTransfers() =>
      _offline.online(_remote.fetchTransfers);

  @override
  Future<void> send({
    required String toLocationId,
    required Map<String, int> quantities,
    String? note,
  }) => _offline.online(
    () => _remote.send(
      toLocationId: toLocationId,
      quantities: quantities,
      note: note,
    ),
  );

  @override
  Future<void> receive(String transferId) =>
      _offline.online(() => _remote.receive(transferId));
}
