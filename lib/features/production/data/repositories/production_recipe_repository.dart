import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/production_recipe.dart';

/// Contract for reading and editing a product's bill of materials — what
/// a production run actually deducts from raw-material stock
/// (supabase/migrations/0006_business_rpcs.sql).
abstract class ProductionRecipeRepository {
  Future<List<ProductionRecipe>> fetchRecipes();

  /// Adds a new line, or — if [product]/[rawMaterialItemId] already has
  /// one — corrects its ratio. Admin/Manager only (enforced by RLS).
  Future<void> saveLine({
    required Product product,
    required String rawMaterialItemId,
    required double quantityUsed,
    required int perBags,
  });

  /// Removes a line entirely. Admin/Manager only (enforced by RLS).
  Future<void> deleteLine(String recipeId);
}

/// Backed by the `production_recipes` table.
class SupabaseProductionRecipeRepository implements ProductionRecipeRepository {
  SupabaseProductionRecipeRepository(this._tenantId);

  /// Every query and write is scoped to this organization.
  final String _tenantId;

  SupabaseClient get _client => Supabase.instance.client;

  static const _selectWithMaterial =
      '*, stock_items(name, unit), products(name, unit)';

  @override
  Future<List<ProductionRecipe>> fetchRecipes() async {
    final rows = await _client
        .from('production_recipes')
        .select(_selectWithMaterial)
        .eq('tenant_id', _tenantId);
    return (rows as List)
        .map((row) => ProductionRecipe.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<void> saveLine({
    required Product product,
    required String rawMaterialItemId,
    required double quantityUsed,
    required int perBags,
  }) {
    return _client.from('production_recipes').upsert({
      'tenant_id': _tenantId,
      'product_id': product.id,
      'raw_material_item_id': rawMaterialItemId,
      'quantity_used': quantityUsed,
      'per_bags': perBags,
    }, onConflict: 'tenant_id,product_id,raw_material_item_id');
  }

  @override
  Future<void> deleteLine(String recipeId) {
    return _client
        .from('production_recipes')
        .delete()
        .eq('tenant_id', _tenantId)
        .eq('id', recipeId);
  }
}
