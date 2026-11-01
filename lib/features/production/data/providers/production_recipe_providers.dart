import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/action_controller.dart';
import '../../../organizations/data/providers/organization_providers.dart';
import '../models/production_recipe.dart';
import '../repositories/production_recipe_repository.dart';

/// The active [ProductionRecipeRepository] implementation.
final productionRecipeRepositoryProvider = Provider<ProductionRecipeRepository>(
  (ref) =>
      SupabaseProductionRecipeRepository(ref.watch(currentTenantIdProvider)),
);

/// Every recipe line, across all products.
final productionRecipesProvider = FutureProvider<List<ProductionRecipe>>((ref) {
  return ref.watch(productionRecipeRepositoryProvider).fetchRecipes();
});

/// Drives the "Manage recipes" screen: loading while a line save/delete
/// is in flight, error (most commonly no connection) if it fails.
class RecipeActionController extends ActionController {
  RecipeActionController(this._ref);

  final Ref _ref;

  Future<bool> saveLine({
    required ProductType product,
    required String rawMaterialItemId,
    required double quantityUsed,
    required int perBags,
  }) async {
    final result = await guard(() async {
      await _ref
          .read(productionRecipeRepositoryProvider)
          .saveLine(
            product: product,
            rawMaterialItemId: rawMaterialItemId,
            quantityUsed: quantityUsed,
            perBags: perBags,
          );
      _ref.invalidate(productionRecipesProvider);
      return true;
    });
    return result ?? false;
  }

  Future<bool> deleteLine(String recipeId) async {
    final result = await guard(() async {
      await _ref.read(productionRecipeRepositoryProvider).deleteLine(recipeId);
      _ref.invalidate(productionRecipesProvider);
      return true;
    });
    return result ?? false;
  }
}

final recipeActionControllerProvider =
    StateNotifierProvider<RecipeActionController, AsyncValue<void>>(
      (ref) => RecipeActionController(ref),
    );
