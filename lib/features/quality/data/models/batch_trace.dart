/// Where a production batch went (`trace_batch`): the run, what is still in
/// stock, its shift's water tests, and every sale that got its bags.
class BatchTrace {
  const BatchTrace({
    required this.batchNumber,
    required this.date,
    required this.shift,
    required this.machine,
    required this.product,
    required this.quantityProduced,
    required this.bagsInStock,
    required this.waterTestsPassed,
    required this.sales,
  });

  final String batchNumber;
  final DateTime date;
  final String shift;
  final String machine;
  final String product;
  final int quantityProduced;
  final int bagsInStock;

  /// null when its shift had no water test; false if any failed.
  final bool? waterTestsPassed;
  final List<BatchSale> sales;

  int get bagsSold => sales
      .where((sale) => !sale.voided)
      .fold(0, (sum, sale) => sum + sale.bags);

  factory BatchTrace.fromJson(Map<String, dynamic> json) {
    final run = json['run'] as Map<String, dynamic>;
    final tests = json['water_tests'] as List? ?? const [];
    return BatchTrace(
      batchNumber: run['batch_number'] as String,
      date: DateTime.parse(run['date'] as String),
      shift: run['shift'] as String,
      machine: run['machine'] as String,
      product: run['product'] as String? ?? '',
      quantityProduced: run['quantity_produced'] as int,
      bagsInStock: (json['bags_in_stock'] as num).toInt(),
      waterTestsPassed: tests.isEmpty
          ? null
          : tests.every((test) => (test as Map)['passed'] == true),
      sales: [
        for (final sale in json['sales'] as List? ?? const [])
          BatchSale.fromJson(sale as Map<String, dynamic>),
      ],
    );
  }
}

/// One sale that got bags from the batch.
class BatchSale {
  const BatchSale({
    required this.saleId,
    required this.dateTime,
    required this.bags,
    required this.voided,
    this.customerName,
    this.customerPhone,
    this.driverName,
  });

  final String saleId;
  final DateTime dateTime;
  final int bags;
  final bool voided;
  final String? customerName;
  final String? customerPhone;

  /// Set when the sale came from a driver's trip.
  final String? driverName;

  factory BatchSale.fromJson(Map<String, dynamic> json) => BatchSale(
    saleId: json['id'] as String,
    dateTime: DateTime.parse(json['date_time'] as String).toLocal(),
    bags: json['bags'] as int,
    voided: json['voided'] as bool? ?? false,
    customerName: json['customer_name'] as String?,
    customerPhone: json['customer_phone'] as String?,
    driverName: json['driver_name'] as String?,
  );
}
