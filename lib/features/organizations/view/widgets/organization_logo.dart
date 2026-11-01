import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../data/providers/organization_providers.dart';

/// The organization's logo in a small square, or a placeholder icon.
class OrganizationLogo extends ConsumerWidget {
  const OrganizationLogo({super.key, this.size = 56});

  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logo = ref.watch(organizationLogoProvider).valueOrNull;
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppRadius.panel),
      ),
      child: logo == null
          ? const Icon(
              Icons.storefront_outlined,
              color: AppColors.textSecondary,
            )
          : Image.memory(logo, fit: BoxFit.contain),
    );
  }
}
