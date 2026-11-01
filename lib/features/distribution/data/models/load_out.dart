import '../../../../core/constants/distribution_rates.dart';
import '../../../../core/constants/product_catalog.dart';

/// Whether a trip is still out or has been reconciled.
enum LoadOutStatus { onRoad, settled }

/// `load_outs.status` is a Postgres enum with a snake_case value for
/// on-road.
LoadOutStatus loadOutStatusFromDb(String value) => switch (value) {
  'on_road' => LoadOutStatus.onRoad,
  'settled' => LoadOutStatus.settled,
  _ => throw ArgumentError('Unknown load-out status: $value'),
};

extension LoadOutStatusDb on LoadOutStatus {
  String get dbValue => switch (this) {
    LoadOutStatus.onRoad => 'on_road',
    LoadOutStatus.settled => 'settled',
  };
}

/// One driver's trip: what went out, and — once settled — what came
/// back. [driverId]/[vehicleId] reference [Driver]/[Vehicle].
class LoadOut {
  const LoadOut({
    required this.id,
    required this.dateTime,
    required this.driverId,
    required this.vehicleId,
    required this.product,
    required this.bagsLoaded,
    required this.status,
    this.note,
    this.bagsSold,
    this.bagsReturned,
    this.bagsDamaged,
    this.cashReturned,
    this.settledAt,
    this.discrepancyNote,
    this.saleId,
  });

  final String id;
  final DateTime dateTime;
  final String driverId;
  final String vehicleId;
  final ProductType product;
  final int bagsLoaded;
  final LoadOutStatus status;
  final String? note;
  final int? bagsSold;
  final int? bagsReturned;
  final int? bagsDamaged;
  final num? cashReturned;
  final DateTime? settledAt;
  final String? discrepancyNote;

  /// Set once settling the trip created a real [Sale] for the bags
  /// sold along the route (only happens when a unit price was given) —
  /// null for a trip that never sold anything, or sold without price
  /// info to record a sale from.
  final String? saleId;

  /// Rough expected takings while still on the road, before it's known
  /// how many bags actually sold.
  num get expectedCashFromLoad => bagsLoaded * DistributionRates.cashPerBag;

  factory LoadOut.fromJson(Map<String, dynamic> json) => LoadOut(
    id: json['id'] as String,
    dateTime: DateTime.parse(json['date_time'] as String),
    driverId: json['driver_id'] as String,
    vehicleId: json['vehicle_id'] as String,
    product: ProductType.values.byName(json['product'] as String),
    bagsLoaded: json['bags_loaded'] as int,
    status: loadOutStatusFromDb(json['status'] as String),
    note: json['note'] as String?,
    bagsSold: json['bags_sold'] as int?,
    bagsReturned: json['bags_returned'] as int?,
    bagsDamaged: json['bags_damaged'] as int?,
    cashReturned: json['cash_returned'] as num?,
    settledAt: json['settled_at'] == null
        ? null
        : DateTime.parse(json['settled_at'] as String),
    discrepancyNote: json['discrepancy_note'] as String?,
    saleId: json['sale_id'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'date_time': dateTime.toIso8601String(),
    'driver_id': driverId,
    'vehicle_id': vehicleId,
    'product': product.name,
    'bags_loaded': bagsLoaded,
    'status': status.dbValue,
    'note': note,
    'bags_sold': bagsSold,
    'bags_returned': bagsReturned,
    'bags_damaged': bagsDamaged,
    'cash_returned': cashReturned,
    'settled_at': settledAt?.toIso8601String(),
    'discrepancy_note': discrepancyNote,
    'sale_id': saleId,
  };
}
