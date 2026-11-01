import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_confirm_dialog.dart';
import '../../data/models/product.dart';
import '../../data/providers/products_providers.dart';

/// Retire / bring back, and delete (only works for a product never used).
class ProductStatusActions extends ConsumerWidget {
  const ProductStatusActions({super.key, required this.product});

  final Product product;

  Future<void> _setRetired(BuildContext context, WidgetRef ref) async {
    final retiring = !product.isRetired;
    final updated = await ref
        .read(productActionControllerProvider.notifier)
        .setRetired(product, retired: retiring);
    if (updated == null || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          retiring
              ? '${product.name} retired. Its history stays.'
              : '${product.name} is back on sale.',
        ),
      ),
    );
    Navigator.of(context).pop();
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Delete ${product.name}?',
      message:
          'Only a product that was never sold, produced, loaded or stocked '
          'can be deleted. Otherwise, retire it instead.',
    );
    if (!confirmed || !context.mounted) return;
    final deleted = await ref
        .read(productActionControllerProvider.notifier)
        .delete(product);
    if (!deleted || !context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('${product.name} deleted.')));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final busy = ref.watch(productActionControllerProvider).isLoading;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          product.isRetired
              ? 'Retired: not offered for new sales, production or load-outs.'
              : 'Stopped making this? Retire it to hide it from new records '
                    'and keep its history.',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          children: [
            AppButton(
              label: product.isRetired ? 'Bring back' : 'Retire',
              variant: AppButtonVariant.secondary,
              onPressed: busy ? null : () => _setRetired(context, ref),
            ),
            AppButton(
              label: 'Delete',
              variant: AppButtonVariant.text,
              onPressed: busy ? null : () => _delete(context, ref),
            ),
          ],
        ),
      ],
    );
  }
}
