/// Kinds of records that can be made without internet. Each matches a
/// branch of `apply_device_operation` (migration 0015) and its payload
/// carries that function's parameters without the `p_` prefix.
enum OperationType {
  sale('sale', 'Sale'),
  customerPayment('customer_payment', 'Debt payment'),
  expense('expense', 'Expense'),
  productionRun('production_run', 'Production run'),
  customer('customer', 'New customer'),
  stockIn('stock_in', 'Stock in'),
  stockCount('stock_count', 'Stock count'),
  loadOut('load_out', 'Load-out'),
  driverReturn('driver_return', 'Driver return'),
  cashCount('cash_count', 'Cash count'),
  waterTest('water_test', 'Water test'),
  sanitationCheck('sanitation_check', 'Sanitation checklist'),
  diesel('diesel', 'Diesel'),
  maintenanceDone('maintenance_done', 'Maintenance done'),
  breakdown('breakdown', 'Breakdown'),
  breakdownEnd('breakdown_end', 'Machine fixed'),
  attendance('attendance', 'Attendance'),
  bagCounts('bag_counts', 'Bag counts');

  const OperationType(this.dbValue, this.label);

  final String dbValue;
  final String label;

  static OperationType fromDb(String value) =>
      values.firstWhere((type) => type.dbValue == value);
}

enum OperationStatus { pending, rejected }

/// One record made on this device, waiting to be sent (or refused by the
/// server and kept so nothing is lost).
class OutboxOperation {
  const OutboxOperation({
    required this.opId,
    required this.seq,
    required this.type,
    required this.actorId,
    required this.actorName,
    required this.recordedAt,
    required this.payload,
    this.status = OperationStatus.pending,
    this.error,
  });

  /// Also the id the record has on this device until it syncs.
  final String opId;

  /// Order the records were made in; they're sent in this order.
  final int seq;
  final OperationType type;
  final String actorId;
  final String actorName;
  final DateTime recordedAt;
  final Map<String, dynamic> payload;
  final OperationStatus status;

  /// Why the server refused it, when [status] is rejected.
  final String? error;

  OutboxOperation copyWith({OperationStatus? status, String? error}) {
    return OutboxOperation(
      opId: opId,
      seq: seq,
      type: type,
      actorId: actorId,
      actorName: actorName,
      recordedAt: recordedAt,
      payload: payload,
      status: status ?? this.status,
      error: error,
    );
  }

  /// What `device-sync` receives.
  Map<String, dynamic> toSyncJson() => {
    'op_id': opId,
    'type': type.dbValue,
    'actor_id': actorId,
    'recorded_at': recordedAt.toUtc().toIso8601String(),
    'payload': payload,
  };

  factory OutboxOperation.fromJson(Map<String, dynamic> json) {
    return OutboxOperation(
      opId: json['op_id'] as String,
      seq: json['seq'] as int,
      type: OperationType.fromDb(json['type'] as String),
      actorId: json['actor_id'] as String,
      actorName: json['actor_name'] as String,
      recordedAt: DateTime.parse(json['recorded_at'] as String),
      payload: Map<String, dynamic>.from(json['payload'] as Map),
      status: OperationStatus.values.byName(json['status'] as String),
      error: json['error'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    ...toSyncJson(),
    'seq': seq,
    'actor_name': actorName,
    'status': status.name,
    'error': error,
  };
}
