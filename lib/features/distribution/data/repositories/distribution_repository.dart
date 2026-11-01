import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/payment_channel.dart';
import '../../../../core/utils/rpc_params.dart';
import '../../../sales/data/models/sale.dart';
import '../models/driver.dart';
import '../models/load_out.dart';
import '../models/vehicle.dart';

/// Contract for reading drivers/vehicles/trips and recording load-outs
/// and settlements.
abstract class DistributionRepository {
  Future<List<Driver>> fetchDrivers();
  Future<List<Vehicle>> fetchVehicles();
  Future<Driver> createDriver({required String name, required String phone});
  Future<Vehicle> createVehicle({required String name});

  /// Trips still on the road, plus those loaded on or after [from] (all
  /// when null). Most recent first.
  Future<List<LoadOut>> fetchLoadOuts({DateTime? from});
  Future<LoadOut> recordLoadOut(LoadOut loadOut);

  /// Bags sold during the trip only create a real [Sale] (visible in
  /// Sales, the customer's debt ledger, and Finance) when [unitPrice]
  /// is given — the trip's own bags-loaded/returned/damaged
  /// reconciliation always happens regardless. Stock for the sold
  /// portion is never deducted again here: `record_load_out` already
  /// deducted the full loaded quantity when the trip started.
  Future<LoadOut> settleTrip({
    required String loadOutId,
    required int bagsSold,
    required int bagsReturned,
    required int bagsDamaged,
    required num cashReturned,
    String? discrepancyNote,
    CustomerType customerType = CustomerType.walkIn,
    String? customerName,
    num? unitPrice,
    num? amountPaid,
    PaymentMethod paymentMethod = PaymentMethod.cash,
    PaymentChannel? paidChannel,
  });
}

/// Backed by `drivers`/`vehicles`/`load_outs`. `recordLoadOut` and
/// `settleTrip` call the `record_load_out`/`settle_load_out` Postgres
/// functions (supabase/migrations/0006_business_rpcs.sql), which also deduct/return the matching
/// finished-goods item in `stock_items` atomically with the trip write.
class SupabaseDistributionRepository implements DistributionRepository {
  SupabaseDistributionRepository(this._tenantId);

  /// Every query and write is scoped to this organization.
  final String _tenantId;

  SupabaseClient get _client => Supabase.instance.client;

  static const _selectLoadOut = '*, products(name, unit)';

  @override
  Future<List<Driver>> fetchDrivers() async {
    final rows = await _client
        .from('drivers')
        .select()
        .eq('tenant_id', _tenantId)
        .order('name');
    return (rows as List)
        .map((row) => Driver.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<List<Vehicle>> fetchVehicles() async {
    final rows = await _client
        .from('vehicles')
        .select()
        .eq('tenant_id', _tenantId)
        .order('name');
    return (rows as List)
        .map((row) => Vehicle.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<Driver> createDriver({
    required String name,
    required String phone,
  }) async {
    final row = await _client
        .from('drivers')
        .insert({'tenant_id': _tenantId, 'name': name, 'phone': phone})
        .select()
        .single();
    return Driver.fromJson(row);
  }

  @override
  Future<Vehicle> createVehicle({required String name}) async {
    final row = await _client
        .from('vehicles')
        .insert({'tenant_id': _tenantId, 'name': name})
        .select()
        .single();
    return Vehicle.fromJson(row);
  }

  @override
  Future<List<LoadOut>> fetchLoadOuts({DateTime? from}) async {
    var query = _client
        .from('load_outs')
        .select(_selectLoadOut)
        .eq('tenant_id', _tenantId);
    if (from != null) {
      query = query.or(
        'status.eq.on_road,date_time.gte.${from.toUtc().toIso8601String()}',
      );
    }
    final rows = await query.order('date_time', ascending: false);
    return (rows as List)
        .map((row) => LoadOut.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  /// record_load_out's values (without the `p_` prefix), shared with
  /// offline mode.
  static Map<String, dynamic> recordLoadOutPayload(LoadOut loadOut) => {
    'driver_id': loadOut.driverId,
    'vehicle_id': loadOut.vehicleId,
    'product_id': loadOut.product.id,
    'bags_loaded': loadOut.bagsLoaded,
    'note': loadOut.note,
  };

  /// settle_load_out's values apart from the trip itself (without the
  /// `p_` prefix), shared with offline mode.
  static Map<String, dynamic> settleTripPayload({
    required int bagsSold,
    required int bagsReturned,
    required int bagsDamaged,
    required num cashReturned,
    String? discrepancyNote,
    CustomerType customerType = CustomerType.walkIn,
    String? customerName,
    num? unitPrice,
    num? amountPaid,
    PaymentMethod paymentMethod = PaymentMethod.cash,
    PaymentChannel? paidChannel,
  }) => {
    'bags_sold': bagsSold,
    'bags_returned': bagsReturned,
    'bags_damaged': bagsDamaged,
    'cash_returned': cashReturned,
    'discrepancy_note': discrepancyNote,
    'customer_type': customerType.dbValue,
    'customer_name': customerName,
    'unit_price': unitPrice,
    'amount_paid': amountPaid,
    'payment_method': paymentMethod.name,
    'paid_channel': paidChannel?.name,
  };

  @override
  Future<LoadOut> recordLoadOut(LoadOut loadOut) async {
    final loadOutId =
        await _client.rpc(
              'record_load_out',
              params: rpcParams(_tenantId, recordLoadOutPayload(loadOut)),
            )
            as String;

    final row = await _client
        .from('load_outs')
        .select(_selectLoadOut)
        .eq('tenant_id', _tenantId)
        .eq('id', loadOutId)
        .single();
    return LoadOut.fromJson(row);
  }

  @override
  Future<LoadOut> settleTrip({
    required String loadOutId,
    required int bagsSold,
    required int bagsReturned,
    required int bagsDamaged,
    required num cashReturned,
    String? discrepancyNote,
    CustomerType customerType = CustomerType.walkIn,
    String? customerName,
    num? unitPrice,
    num? amountPaid,
    PaymentMethod paymentMethod = PaymentMethod.cash,
    PaymentChannel? paidChannel,
  }) async {
    await _client.rpc(
      'settle_load_out',
      params: rpcParams(_tenantId, {
        'load_out_id': loadOutId,
        ...settleTripPayload(
          bagsSold: bagsSold,
          bagsReturned: bagsReturned,
          bagsDamaged: bagsDamaged,
          cashReturned: cashReturned,
          discrepancyNote: discrepancyNote,
          customerType: customerType,
          customerName: customerName,
          unitPrice: unitPrice,
          amountPaid: amountPaid,
          paymentMethod: paymentMethod,
          paidChannel: paidChannel,
        ),
      }),
    );
    final row = await _client
        .from('load_outs')
        .select(_selectLoadOut)
        .eq('tenant_id', _tenantId)
        .eq('id', loadOutId)
        .single();
    return LoadOut.fromJson(row);
  }
}
