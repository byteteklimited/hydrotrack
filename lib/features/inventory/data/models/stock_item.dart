import '../../../../core/constants/product_catalog.dart';

export '../../../../core/constants/product_catalog.dart';

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
/// the point at which it should be reordered. [productType] links a
/// finished-goods item to the product a load-out can deduct against —
/// always null for raw materials, and optional even for finished goods
/// (an item with no link just never auto-deducts).
class StockItem {
  const StockItem({
    required this.id,
    required this.name,
    required this.category,
    required this.unit,
    required this.quantityOnHand,
    required this.reorderLevel,
    this.productType,
  });

  final String id;
  final String name;
  final StockCategory category;
  final String unit;
  final int quantityOnHand;
  final int reorderLevel;
  final ProductType? productType;

  /// What to actually show for this item. [name] is free text an admin
  /// typed when the catalog entry was created — fine for a raw material,
  /// but for a finished-goods item linked to a [productType] it can
  /// silently drift from the name every other screen (Sales, Production)
  /// already shows for that same product via the shared catalog. Prefer
  /// the catalog's own label whenever one exists, so Inventory can't be
  /// the one screen calling a 50cl Sachet something else.
  String get displayName => productType?.label ?? name;

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
      productType: productType,
    );
  }

  factory StockItem.fromJson(Map<String, dynamic> json) => StockItem(
    id: json['id'] as String,
    name: json['name'] as String,
    category: _categoryFromDb(json['category'] as String),
    unit: json['unit'] as String,
    quantityOnHand: json['quantity_on_hand'] as int,
    reorderLevel: json['reorder_level'] as int,
    productType: json['product_type'] == null
        ? null
        : ProductType.values.byName(json['product_type'] as String),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'category': stockCategoryToDb(category),
    'unit': unit,
    'quantity_on_hand': quantityOnHand,
    'reorder_level': reorderLevel,
    'product_type': productType?.name,
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
