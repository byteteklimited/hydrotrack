import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/payment_channel.dart';
import '../../../../core/utils/query_range.dart';
import '../../../../core/utils/rpc_params.dart';
import '../../../offline/data/services/offline_context.dart';
import '../models/purchase.dart';
import '../models/supplier.dart';

/// Suppliers, purchases and supplier payments (migration 0021). Owner,
/// Admin, Manager and Store keeper; paying suppliers is Owner/Admin/
/// Manager (enforced by the server). Needs internet.
abstract class PurchasesRepository {
  Future<List<Supplier>> fetchSuppliers();
  Future<Supplier> createSupplier({required String name, String? phone});
  Future<List<SupplierLedgerEntry>> fetchSupplierLedger(String supplierId);

  /// Newest first; purchase dates on or after [from].
  Future<List<Purchase>> fetchPurchases({DateTime? from});

  Future<void> recordPurchase({
    required String supplierId,
    required DateTime date,
    required List<PurchaseLine> lines,
    required num amountPaid,
    PaymentChannel? paidChannel,
    String? note,
  });

  Future<void> paySupplier({
    required String supplierId,
    required num amount,
    required PaymentChannel channel,
    required DateTime date,
    String? note,
  });
}

class SupabasePurchasesRepository implements PurchasesRepository {
  SupabasePurchasesRepository(this._tenantId);

  final String _tenantId;

  SupabaseClient get _client => Supabase.instance.client;

  static const _selectPurchase =
      '*, suppliers(name), purchase_lines(*, stock_items(name, unit)), '
      'profiles!recorded_by(full_name)';

  @override
  Future<List<Supplier>> fetchSuppliers() async {
    final rows = await _client
        .from('suppliers')
        .select()
        .eq('tenant_id', _tenantId)
        .order('name');
    return [
      for (final row in rows as List)
        Supplier.fromJson(row as Map<String, dynamic>),
    ];
  }

  @override
  Future<Supplier> createSupplier({required String name, String? phone}) async {
    final row = await _client.rpc(
      'create_supplier',
      params: rpcParams(_tenantId, {'name': name, 'phone': phone}),
    );
    return Supplier.fromJson(row as Map<String, dynamic>);
  }

  @override
  Future<List<SupplierLedgerEntry>> fetchSupplierLedger(
    String supplierId,
  ) async {
    final rows = await _client
        .from('supplier_ledger')
        .select()
        .eq('tenant_id', _tenantId)
        .eq('supplier_id', supplierId)
        .order('date', ascending: false)
        .order('created_at', ascending: false);
    return [
      for (final row in rows as List)
        SupplierLedgerEntry.fromJson(row as Map<String, dynamic>),
    ];
  }

  @override
  Future<List<Purchase>> fetchPurchases({DateTime? from}) async {
    final rows = await _client
        .from('purchases')
        .select(_selectPurchase)
        .eq('tenant_id', _tenantId)
        .inRange('date', from: from, dateOnly: true)
        .order('date', ascending: false)
        .order('created_at', ascending: false);
    return [
      for (final row in rows as List)
        Purchase.fromJson(row as Map<String, dynamic>),
    ];
  }

  @override
  Future<void> recordPurchase({
    required String supplierId,
    required DateTime date,
    required List<PurchaseLine> lines,
    required num amountPaid,
    PaymentChannel? paidChannel,
    String? note,
  }) {
    return _client.rpc(
      'record_purchase',
      params: rpcParams(_tenantId, {
        'supplier_id': supplierId,
        'date': dateParam(date),
        'lines': [for (final line in lines) line.toPayload()],
        'amount_paid': amountPaid,
        'paid_channel': paidChannel?.name,
        'note': note,
      }),
    );
  }

  @override
  Future<void> paySupplier({
    required String supplierId,
    required num amount,
    required PaymentChannel channel,
    required DateTime date,
    String? note,
  }) {
    return _client.rpc(
      'pay_supplier',
      params: rpcParams(_tenantId, {
        'supplier_id': supplierId,
        'amount': amount,
        'channel': channel.name,
        'date': dateParam(date),
        'note': note,
      }),
    );
  }
}

/// On a set-up device: purchases need internet (with a clear message
/// when there isn't any) — suppliers aren't kept on the device.
class OfflinePurchasesRepository implements PurchasesRepository {
  OfflinePurchasesRepository(this._remote, this._offline);

  final PurchasesRepository _remote;
  final OfflineContext _offline;

  @override
  Future<List<Supplier>> fetchSuppliers() =>
      _offline.online(_remote.fetchSuppliers);

  @override
  Future<Supplier> createSupplier({required String name, String? phone}) =>
      _offline.online(() => _remote.createSupplier(name: name, phone: phone));

  @override
  Future<List<SupplierLedgerEntry>> fetchSupplierLedger(String supplierId) =>
      _offline.online(() => _remote.fetchSupplierLedger(supplierId));

  @override
  Future<List<Purchase>> fetchPurchases({DateTime? from}) =>
      _offline.online(() => _remote.fetchPurchases(from: from));

  @override
  Future<void> recordPurchase({
    required String supplierId,
    required DateTime date,
    required List<PurchaseLine> lines,
    required num amountPaid,
    PaymentChannel? paidChannel,
    String? note,
  }) => _offline.online(
    () => _remote.recordPurchase(
      supplierId: supplierId,
      date: date,
      lines: lines,
      amountPaid: amountPaid,
      paidChannel: paidChannel,
      note: note,
    ),
  );

  @override
  Future<void> paySupplier({
    required String supplierId,
    required num amount,
    required PaymentChannel channel,
    required DateTime date,
    String? note,
  }) => _offline.online(
    () => _remote.paySupplier(
      supplierId: supplierId,
      amount: amount,
      channel: channel,
      date: date,
      note: note,
    ),
  );
}
