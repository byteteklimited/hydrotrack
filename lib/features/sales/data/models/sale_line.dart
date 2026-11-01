import '../../../products/data/models/product.dart';

export '../../../products/data/models/product.dart';

/// One product line within a sale: what was sold, how many, at what price
/// per unit, and the product's list price for that customer at the time
/// (so a price a manager changed stays visible).
class SaleLine {
  const SaleLine({
    required this.product,
    required this.quantity,
    required this.unitPrice,
    this.listPrice,
  });

  final Product product;
  final int quantity;
  final num unitPrice;

  /// Null on sales recorded before products had prices.
  final num? listPrice;

  num get lineTotal => quantity * unitPrice;

  bool get priceChanged => listPrice != null && listPrice != unitPrice;

  factory SaleLine.fromJson(Map<String, dynamic> json) => SaleLine(
    product: Product.fromRecord(json),
    quantity: json['quantity'] as int,
    unitPrice: json['unit_price'] as num,
    listPrice: json['list_price'] as num?,
  );

  Map<String, dynamic> toJson() => {
    ...product.toRecordJson(),
    'quantity': quantity,
    'unit_price': unitPrice,
    'list_price': listPrice,
  };
}
