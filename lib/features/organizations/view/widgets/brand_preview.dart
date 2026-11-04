import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/brand_palette.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_status_tag.dart';

/// A small piece of the app drawn in [palette], so the owner sees their
/// colors before saving.
class BrandPreview extends StatelessWidget {
  const BrandPreview({super.key, required this.palette, required this.name});

  final BrandPalette palette;
  final String name;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.forBrand(palette),
      child: Builder(
        builder: (context) {
          final brand = context.brand;
          final theme = Theme.of(context);
          return AppCard(
            title: 'Preview',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: brand.accentTint,
                    borderRadius: BorderRadius.circular(AppRadius.button),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.home_outlined, color: brand.primaryText),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        'Home',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: brand.primaryText,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  name.isEmpty ? 'Your business' : name,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: brand.primaryText,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    AppButton(label: 'Record sale', onPressed: () {}),
                    const SizedBox(width: AppSpacing.sm),
                    AppStatusTag(label: 'Selected', color: brand.primaryText),
                  ],
                ),
                if (BrandPalette.contrast(
                      palette.primary,
                      AppColors.surfaceWhite,
                    ) <
                    BrandPalette.minTextContrast) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Text in your main color is shown a little darker so it '
                    'stays easy to read.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
