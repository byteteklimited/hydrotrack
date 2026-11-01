import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_error_state.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../../../core/widgets/app_modal.dart';
import '../../../../core/widgets/responsive_center.dart';
import '../../data/models/product.dart';
import '../../data/providers/products_providers.dart';
import '../widgets/product_tile.dart';
import 'product_form_screen.dart';

/// Owner/Admin: the products this factory sells and makes, with their
/// walk-in and distributor prices. Retired products are listed last.
class ProductsScreen extends ConsumerWidget {
  const ProductsScreen({super.key});

  static const _maxContentWidth = 720.0;

  void _open(BuildContext context, [Product? product]) {
    showAppModal<void>(
      context,
      builder: (_) => ProductFormScreen(product: product),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(productsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Products & prices')),
      floatingActionButton: AppButton(
        label: 'Add product',
        leadingIcon: Icons.add,
        onPressed: () => _open(context),
      ),
      body: productsAsync.when(
        loading: () => const AppLoading(message: 'Loading products…'),
        error: (error, stackTrace) => AppErrorState(
          message:
              "Couldn't load products. Check your connection and try again.",
          onRetry: () => ref.invalidate(productsProvider),
        ),
        data: (products) {
          if (products.isEmpty) {
            return AppEmptyState(
              icon: Icons.sell_outlined,
              title: 'No products yet',
              message:
                  'Add what you sell (e.g. 50cl Sachet in bags) with its '
                  'walk-in and distributor prices.',
              actionLabel: 'Add product',
              onAction: () => _open(context),
            );
          }
          final active = products.where((p) => !p.isRetired);
          final retired = products.where((p) => p.isRetired);
          return ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.xxl * 2,
            ),
            children: [
              ResponsiveCenter(
                maxWidth: _maxContentWidth,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Sales fill in these prices automatically. Only '
                      'owners, admins and managers can change a price on a '
                      'sale.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    for (final product in [...active, ...retired])
                      ProductTile(
                        product: product,
                        onTap: () => _open(context, product),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
