import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/payment_channel.dart';
import '../models/sale.dart';

/// Contract for reading and recording sales.
abstract class SalesRepository {
  Future<List<Sale>> fetchSales();
  Future<List<String>> fetchDistributorNames();

  /// [paidChannel] is only meaningful (and required, enforced server-
  /// side) when [sale.paymentMethod] is [PaymentMethod.part] and
  /// something was actually paid — for `cash`/`transfer` the channel
  /// already *is* the payment method, and `credit` pays nothing.
  Future<Sale> recordSale(Sale sale, {PaymentChannel? paidChannel});

  /// Voids a sale — never deletes it. Reverses stock, any debt-ledger
  /// entry, and any cash entry this sale created (supabase/migrations/0006_business_rpcs.sql),
  /// then marks it voided with [reason], the acting staff member, and a
  /// timestamp. Admin only, enforced server-side.
  Future<void> voidSale({required String saleId, required String reason});
}

/// Backed by `sales`/`sale_lines`. `recordSale` calls the `record_sale`
/// Postgres function (supabase/migrations/0006_business_rpcs.sql) so the sale and its line items
/// commit in one transaction. Distributor names come from the `customers`
/// table (Debts) — one shared customer directory, not a separate list.
class SupabaseSalesRepository implements SalesRepository {
  SupabaseSalesRepository(this._tenantId);

  /// Every query and write is scoped to this organization.
  final String _tenantId;

  SupabaseClient get _client => Supabase.instance.client;

  static const _selectFull =
      '*, sale_lines(*), profiles!recorded_by(full_name), '
      'voided_by_profile:profiles!voided_by(full_name)';

  @override
  Future<List<Sale>> fetchSales() async {
    final rows = await _client
        .from('sales')
        .select(_selectFull)
        .eq('tenant_id', _tenantId)
        .order('date_time', ascending: false);
    return (rows as List)
        .map((row) => Sale.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<List<String>> fetchDistributorNames() async {
    final rows = await _client
        .from('customers')
        .select('name')
        .eq('tenant_id', _tenantId)
        .order('name');
    return (rows as List)
        .map((row) => (row as Map<String, dynamic>)['name'] as String)
        .toList();
  }

  @override
  Future<Sale> recordSale(Sale sale, {PaymentChannel? paidChannel}) async {
    final saleId =
        await _client.rpc(
              'record_sale',
              params: {
                'p_tenant_id': _tenantId,
                'p_customer_type': sale.customerType.dbValue,
                'p_customer_name': sale.customerName,
                'p_total': sale.total,
                'p_amount_paid': sale.amountPaid,
                'p_payment_method': sale.paymentMethod.name,
                'p_balance': sale.balance,
                'p_lines': [
                  for (final line in sale.lines)
                    {
                      'product': line.product.name,
                      'quantity': line.quantity,
                      'unit_price': line.unitPrice,
                    },
                ],
                'p_paid_channel': paidChannel?.name,
              },
            )
            as String;

    final row = await _client
        .from('sales')
        .select(_selectFull)
        .eq('tenant_id', _tenantId)
        .eq('id', saleId)
        .single();
    return Sale.fromJson(row);
  }

  @override
  Future<void> voidSale({required String saleId, required String reason}) {
    return _client.rpc(
      'void_sale',
      params: {
        'p_tenant_id': _tenantId,
        'p_sale_id': saleId,
        'p_reason': reason,
      },
    );
  }
}
