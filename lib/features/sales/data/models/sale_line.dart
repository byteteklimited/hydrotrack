import '../../../../core/constants/product_catalog.dart';

/// One product line within a sale — what was sold, how many, and at what
/// price per unit.
class SaleLine {
  const SaleLine({
    required this.product,
    required this.quantity,
    required this.unitPrice,
  });

  final ProductType product;
  final int quantity;
  final num unitPrice;

  num get lineTotal => quantity * unitPrice;

  factory SaleLine.fromJson(Map<String, dynamic> json) => SaleLine(
    product: ProductType.values.byName(json['product'] as String),
    quantity: json['quantity'] as int,
    unitPrice: json['unit_price'] as num,
  );

  Map<String, dynamic> toJson() => {
    'product': product.name,
    'quantity': quantity,
    'unit_price': unitPrice,
  };
}
