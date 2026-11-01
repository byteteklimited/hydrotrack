import '../../../products/data/models/product.dart';

export '../../../products/data/models/product.dart';

/// One raw-material line in a product's bill of materials: "[quantityUsed]
/// [rawMaterialUnit] of [rawMaterialName] makes [perBags] bags of
/// [product]". Stored as those two whole numbers, not a pre-divided
/// ratio, so the edit form can show back exactly what was typed.
class ProductionRecipe {
  const ProductionRecipe({
    required this.id,
    required this.product,
    required this.rawMaterialItemId,
    required this.rawMaterialName,
    required this.rawMaterialUnit,
    required this.quantityUsed,
    required this.perBags,
  });

  final String id;
  final Product product;
  final String rawMaterialItemId;
  final String rawMaterialName;
  final String rawMaterialUnit;
  final double quantityUsed;
  final int perBags;

  /// How much raw material one bag (good or wasted) of [product] actually
  /// consumes — the figure a production run's deduction is based on.
  double get quantityPerBag => quantityUsed / perBags;

  /// `raw_material_item_id` is a Postgres FK to `stock_items`, so a row
  /// fetched from Supabase carries the joined name/unit here instead of
  /// just the raw id.
  factory ProductionRecipe.fromJson(Map<String, dynamic> json) {
    final item = json['stock_items'] as Map<String, dynamic>?;
    return ProductionRecipe(
      id: json['id'] as String,
      product: Product.fromRecord(json),
      rawMaterialItemId: json['raw_material_item_id'] as String,
      rawMaterialName: item?['name'] as String? ?? 'Unknown material',
      rawMaterialUnit: item?['unit'] as String? ?? '',
      quantityUsed: (json['quantity_used'] as num).toDouble(),
      perBags: json['per_bags'] as int,
    );
  }
}
