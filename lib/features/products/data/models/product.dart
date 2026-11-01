/// Something a factory sells and produces (e.g. "50cl Sachet", sold in
/// bags). Each organization manages its own list; each product has its
/// own finished-goods stock item and two prices.
///
/// Records (sale lines, production runs, load-outs, recipes, stock items)
/// carry the product as `product_id` plus an embedded
/// `products(name, unit)`; [Product.fromRecord] reads that, without
/// prices. Two products are equal when they have the same id.
class Product {
  const Product({
    required this.id,
    required this.name,
    required this.unit,
    this.walkInPrice = 0,
    this.distributorPrice = 0,
    this.sortOrder = 0,
    this.retiredAt,
  });

  final String id;
  final String name;

  /// What it's counted in: bags, packs, bottles…
  final String unit;
  final num walkInPrice;
  final num distributorPrice;
  final int sortOrder;

  /// Set when retired: hidden from new records, history kept.
  final DateTime? retiredAt;

  bool get isRetired => retiredAt != null;
  String get label => name;

  num priceFor({required bool distributor}) =>
      distributor ? distributorPrice : walkInPrice;

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] as String,
      name: json['name'] as String,
      unit: json['unit'] as String,
      walkInPrice: json['walk_in_price'] as num,
      distributorPrice: json['distributor_price'] as num,
      sortOrder: json['sort_order'] as int? ?? 0,
      retiredAt: json['archived_at'] == null
          ? null
          : DateTime.parse(json['archived_at'] as String),
    );
  }

  /// From a record with `product_id` and `products(name, unit)`.
  factory Product.fromRecord(Map<String, dynamic> json) {
    final embedded = json['products'] as Map<String, dynamic>?;
    return Product(
      id: json['product_id'] as String,
      name: embedded?['name'] as String? ?? 'Product',
      unit: embedded?['unit'] as String? ?? 'units',
    );
  }

  /// The `product_id` + `products(...)` part of a record.
  Map<String, dynamic> toRecordJson() => {
    'product_id': id,
    'products': {'name': name, 'unit': unit},
  };

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'unit': unit,
    'walk_in_price': walkInPrice,
    'distributor_price': distributorPrice,
    'sort_order': sortOrder,
    'archived_at': retiredAt?.toUtc().toIso8601String(),
  };

  @override
  bool operator ==(Object other) => other is Product && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// Products in the organization's own order.
List<Product> sortProducts(Iterable<Product> products) =>
    products.toList()..sort(
      (a, b) => a.sortOrder != b.sortOrder
          ? a.sortOrder.compareTo(b.sortOrder)
          : a.name.compareTo(b.name),
    );
