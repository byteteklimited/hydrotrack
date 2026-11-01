import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/payment_channel.dart';
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
  Future<List<LoadOut>> fetchLoadOuts();
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
  Future<List<LoadOut>> fetchLoadOuts() async {
    final rows = await _client
        .from('load_outs')
        .select()
        .eq('tenant_id', _tenantId)
        .order('date_time', ascending: false);
    return (rows as List)
        .map((row) => LoadOut.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<LoadOut> recordLoadOut(LoadOut loadOut) async {
    final loadOutId =
        await _client.rpc(
              'record_load_out',
              params: {
                'p_tenant_id': _tenantId,
                'p_driver_id': loadOut.driverId,
                'p_vehicle_id': loadOut.vehicleId,
                'p_product': loadOut.product.name,
                'p_bags_loaded': loadOut.bagsLoaded,
                'p_note': loadOut.note,
              },
            )
            as String;

    final row = await _client
        .from('load_outs')
        .select()
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
    final row = await _client.rpc(
      'settle_load_out',
      params: {
        'p_tenant_id': _tenantId,
        'p_load_out_id': loadOutId,
        'p_bags_sold': bagsSold,
        'p_bags_returned': bagsReturned,
        'p_bags_damaged': bagsDamaged,
        'p_cash_returned': cashReturned,
        'p_discrepancy_note': discrepancyNote,
        'p_customer_type': customerType.dbValue,
        'p_customer_name': customerName,
        'p_unit_price': unitPrice,
        'p_amount_paid': amountPaid,
        'p_payment_method': paymentMethod.name,
        'p_paid_channel': paidChannel?.name,
      },
    );
    return LoadOut.fromJson(row as Map<String, dynamic>);
  }
}
