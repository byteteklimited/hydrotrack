import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/action_error.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_confirm_dialog.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_error_state.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../../../core/widgets/app_modal.dart';
import '../../data/models/production_recipe.dart';
import '../../data/providers/production_recipe_providers.dart';
import 'add_recipe_line_screen.dart';

/// Same reasoning as every other list screen in the app: content reads
/// best at a bounded width, implemented as responsive padding so
/// `ListView` keeps its native scroll behavior.
const double _contentCap = 900;

/// What each production run actually deducts from raw-material stock —
/// grouped by product so it reads like "this is what a bag of sachet
/// water takes to make", not a flat unordered table.
class ManageRecipesScreen extends ConsumerWidget {
  const ManageRecipesScreen({super.key});

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    ProductionRecipe line,
  ) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Remove this recipe line?',
      message:
          'Future ${line.product.label} runs will stop deducting '
          '${line.rawMaterialName}. Past deductions are unaffected.',
    );
    if (!confirmed) return;
    if (!context.mounted) return;

    final success = await ref
        .read(recipeActionControllerProvider.notifier)
        .deleteLine(line.id);
    if (!context.mounted) return;

    if (!success) {
      showActionErrorSnackBar(context);
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Recipe line removed')));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recipesAsync = ref.watch(productionRecipesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Recipes')),
      floatingActionButton: AppButton(
        label: 'Add recipe line',
        leadingIcon: Icons.add,
        onPressed: () =>
            showAppModal(context, builder: (_) => const AddRecipeLineScreen()),
      ),
      body: recipesAsync.when(
        data: (recipes) {
          if (recipes.isEmpty) {
            return const AppEmptyState(
              icon: Icons.science_outlined,
              title: 'No recipes defined',
              message:
                  'Production runs will record output but won\'t deduct any '
                  'raw material until you define what each product uses. '
                  'Add the first line to get started.',
            );
          }

          final grouped = <ProductType, List<ProductionRecipe>>{};
          for (final line in recipes) {
            grouped.putIfAbsent(line.product, () => []).add(line);
          }

          return LayoutBuilder(
            builder: (context, constraints) {
              final horizontalPadding = constraints.maxWidth > _contentCap
                  ? (constraints.maxWidth - _contentCap) / 2
                  : AppSpacing.lg;

              return ListView(
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  AppSpacing.lg,
                  horizontalPadding,
                  AppSpacing.xxl,
                ),
                children: [
                  for (final product in grouped.keys) ...[
                    Text(
                      product.label,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    for (final line in grouped[product]!) ...[
                      AppCard(
                        onTap: () => showAppModal(
                          context,
                          builder: (_) =>
                              AddRecipeLineScreen(existingLine: line),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${line.quantityUsed.toStringAsFixed(line.quantityUsed.truncateToDouble() == line.quantityUsed ? 0 : 2)} '
                                '${line.rawMaterialUnit} of ${line.rawMaterialName} '
                                'makes ${line.perBags} bags',
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline),
                              tooltip: 'Remove line',
                              onPressed: () => _delete(context, ref, line),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                    ],
                    const SizedBox(height: AppSpacing.md),
                  ],
                ],
              );
            },
          );
        },
        loading: () => const AppLoading(message: 'Loading recipes…'),
        error: (error, stackTrace) => AppErrorState(
          message:
              "Couldn't load recipes. Check your connection and try again.",
          onRetry: () => ref.invalidate(productionRecipesProvider),
        ),
      ),
    );
  }
}
