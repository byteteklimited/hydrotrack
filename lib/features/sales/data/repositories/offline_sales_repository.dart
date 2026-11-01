import '../../../../core/constants/payment_channel.dart';
import '../../../offline/data/models/outbox_operation.dart';
import '../../../offline/data/services/offline_context.dart';
import '../models/sale.dart';
import 'sales_repository.dart';

/// Sales on a device set up for offline use: recorded on the device first
/// (then sent), read from the server when reachable or the device's copy
/// when not. Voiding needs internet.
class OfflineSalesRepository implements SalesRepository {
  OfflineSalesRepository(this._remote, this._offline);

  final SalesRepository _remote;
  final OfflineContext _offline;

  @override
  Future<List<Sale>> fetchSales() {
    return _offline.read(
      remote: _remote.fetchSales,
      local: (snapshot) =>
          snapshot.rows('sales').map(Sale.fromJson).toList()
            ..sort((a, b) => b.dateTime.compareTo(a.dateTime)),
    );
  }

  @override
  Future<List<String>> fetchDistributorNames() {
    return _offline.read(
      remote: _remote.fetchDistributorNames,
      local: (snapshot) => [
        for (final customer in snapshot.rows('customers'))
          customer['name'] as String,
      ]..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase())),
    );
  }

  @override
  Future<Sale> recordSale(Sale sale, {PaymentChannel? paidChannel}) async {
    final operation = await _offline.record(
      OperationType.sale,
      SupabaseSalesRepository.recordSalePayload(sale, paidChannel),
    );
    return Sale.fromJson(_offline.snapshot.row('sales', operation.opId)!);
  }

  @override
  Future<void> voidSale({required String saleId, required String reason}) {
    return _offline.online(
      () => _remote.voidSale(
        saleId: _offline.serverIdOr(
          saleId,
          notSyncedMessage:
              "This sale hasn't reached the server yet. Void it once it has "
              'synced.',
        ),
        reason: reason,
      ),
    );
  }
}
