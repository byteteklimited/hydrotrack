import '../../../../core/constants/payment_channel.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../offline/data/models/outbox_operation.dart';
import '../../../offline/data/services/offline_context.dart';
import '../../../sales/data/models/sale.dart';
import '../models/driver.dart';
import '../models/load_out.dart';
import '../models/vehicle.dart';
import 'distribution_repository.dart';

/// Distribution on a device set up for offline use: load-outs and driver
/// returns are recorded on the device first; adding drivers or vehicles
/// needs internet.
class OfflineDistributionRepository implements DistributionRepository {
  OfflineDistributionRepository(this._remote, this._offline);

  final DistributionRepository _remote;
  final OfflineContext _offline;

  @override
  Future<List<Driver>> fetchDrivers() {
    return _offline.read(
      remote: _remote.fetchDrivers,
      local: (snapshot) =>
          snapshot.rows('drivers').map(Driver.fromJson).toList()
            ..sort((a, b) => a.name.compareTo(b.name)),
    );
  }

  @override
  Future<List<Vehicle>> fetchVehicles() {
    return _offline.read(
      remote: _remote.fetchVehicles,
      local: (snapshot) =>
          snapshot.rows('vehicles').map(Vehicle.fromJson).toList()
            ..sort((a, b) => a.name.compareTo(b.name)),
    );
  }

  @override
  Future<Driver> createDriver({required String name, required String phone}) {
    return _offline.online(
      () => _remote.createDriver(name: name, phone: phone),
    );
  }

  @override
  Future<Vehicle> createVehicle({required String name}) {
    return _offline.online(() => _remote.createVehicle(name: name));
  }

  @override
  Future<List<LoadOut>> fetchLoadOuts({DateTime? from}) {
    return _offline.read(
      remote: () => _remote.fetchLoadOuts(from: from),
      local: (snapshot) =>
          snapshot
              .rows('load_outs')
              .map(LoadOut.fromJson)
              .where(
                (l) =>
                    l.status == LoadOutStatus.onRoad ||
                    isInRange(l.dateTime, from: from),
              )
              .toList()
            ..sort((a, b) => b.dateTime.compareTo(a.dateTime)),
    );
  }

  @override
  Future<LoadOut> recordLoadOut(LoadOut loadOut) async {
    final operation = await _offline.record(
      OperationType.loadOut,
      SupabaseDistributionRepository.recordLoadOutPayload(loadOut),
    );
    return LoadOut.fromJson(
      _offline.snapshot.row('load_outs', operation.opId)!,
    );
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
    // A trip loaded on this device is matched on the server by the
    // load-out record's id (it gets a new id there).
    final localOpId =
        _offline.snapshot.row('load_outs', loadOutId)?['local_op_id']
            as String?;
    await _offline.record(OperationType.driverReturn, {
      if (localOpId == null)
        'load_out_id': loadOutId
      else
        'load_out_op_id': localOpId,
      ...SupabaseDistributionRepository.settleTripPayload(
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
    });
    return LoadOut.fromJson(_offline.snapshot.row('load_outs', loadOutId)!);
  }
}
