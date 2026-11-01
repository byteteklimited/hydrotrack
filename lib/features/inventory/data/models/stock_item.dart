import '../../../products/data/models/product.dart';

export '../../../products/data/models/product.dart';

/// Which side of the ledger an item belongs to.
enum StockCategory { rawMaterial, finishedGoods }

extension StockCategoryLabel on StockCategory {
  String get label => switch (this) {
    StockCategory.rawMaterial => 'Raw material',
    StockCategory.finishedGoods => 'Finished goods',
  };
}

/// A finer-grained read than [StockItem.isLowStock] — zero on hand is
/// genuinely more severe than "will need reordering soon" and gets its
/// own status instead of being lumped in with it.
enum StockStatus { outOfStock, runningLow, healthy }

extension StockStatusLabel on StockStatus {
  String get label => switch (this) {
    StockStatus.outOfStock => 'Out of stock',
    StockStatus.runningLow => 'Running low',
    StockStatus.healthy => 'Healthy',
  };
}

/// A raw material or finished-goods line item, with its current level and
/// the point at which it should be reordered. [product] is set on a
/// product's own finished-goods item (sales, production and load-outs
/// move it); null for raw materials.
class StockItem {
  const StockItem({
    required this.id,
    required this.name,
    required this.category,
    required this.unit,
    required this.quantityOnHand,
    required this.reorderLevel,
    this.product,
  });

  final String id;
  final String name;
  final StockCategory category;
  final String unit;
  final int quantityOnHand;
  final int reorderLevel;
  final Product? product;

  /// The product's own name for a product's item (the same name Sales
  /// and Production show), otherwise the item's name.
  String get displayName => product?.name ?? name;

  bool get isLowStock => quantityOnHand <= reorderLevel;

  StockStatus get status {
    if (quantityOnHand <= 0) return StockStatus.outOfStock;
    if (quantityOnHand <= reorderLevel) return StockStatus.runningLow;
    return StockStatus.healthy;
  }

  StockItem copyWith({int? quantityOnHand}) {
    return StockItem(
      id: id,
      name: name,
      category: category,
      unit: unit,
      quantityOnHand: quantityOnHand ?? this.quantityOnHand,
      reorderLevel: reorderLevel,
      product: product,
    );
  }

  factory StockItem.fromJson(Map<String, dynamic> json) => StockItem(
    id: json['id'] as String,
    name: json['name'] as String,
    category: _categoryFromDb(json['category'] as String),
    unit: json['unit'] as String,
    quantityOnHand: json['quantity_on_hand'] as int,
    reorderLevel: json['reorder_level'] as int,
    // A product's item has the product's name and unit (kept in step by
    // update_product), so they stand in when the embed isn't selected.
    product: json['product_id'] == null
        ? null
        : Product.fromRecord({
            ...json,
            'products':
                json['products'] ??
                {'name': json['name'], 'unit': json['unit']},
          }),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'category': stockCategoryToDb(category),
    'unit': unit,
    'quantity_on_hand': quantityOnHand,
    'reorder_level': reorderLevel,
    ...?product?.toRecordJson(),
  };
}

/// `stock_items.category` is a Postgres enum with snake_case values.
StockCategory _categoryFromDb(String value) => switch (value) {
  'raw_material' => StockCategory.rawMaterial,
  'finished_goods' => StockCategory.finishedGoods,
  _ => throw ArgumentError('Unknown stock category: $value'),
};

String stockCategoryToDb(StockCategory category) => switch (category) {
  StockCategory.rawMaterial => 'raw_material',
  StockCategory.finishedGoods => 'finished_goods',
};
