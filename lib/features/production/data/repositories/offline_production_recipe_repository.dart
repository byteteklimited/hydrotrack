import '../../../offline/data/services/offline_context.dart';
import '../models/production_recipe.dart';
import 'production_recipe_repository.dart';

/// Recipes on a device set up for offline use: readable offline (needed
/// to record production); changing them needs internet.
class OfflineProductionRecipeRepository implements ProductionRecipeRepository {
  OfflineProductionRecipeRepository(this._remote, this._offline);

  final ProductionRecipeRepository _remote;
  final OfflineContext _offline;

  @override
  Future<List<ProductionRecipe>> fetchRecipes() {
    return _offline.read(
      remote: _remote.fetchRecipes,
      local: (snapshot) =>
          snapshot
              .rows('production_recipes')
              .map(ProductionRecipe.fromJson)
              .toList()
            ..sort((a, b) => a.product.name.compareTo(b.product.name)),
    );
  }

  @override
  Future<void> saveLine({
    required ProductType product,
    required String rawMaterialItemId,
    required double quantityUsed,
    required int perBags,
  }) {
    return _offline.online(
      () => _remote.saveLine(
        product: product,
        rawMaterialItemId: rawMaterialItemId,
        quantityUsed: quantityUsed,
        perBags: perBags,
      ),
    );
  }

  @override
  Future<void> deleteLine(String recipeId) {
    return _offline.online(() => _remote.deleteLine(recipeId));
  }
}
