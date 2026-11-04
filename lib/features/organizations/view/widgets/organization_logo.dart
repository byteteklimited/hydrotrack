import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/brand_palette.dart';
import '../../data/models/organization.dart';
import '../../data/providers/organization_providers.dart';

/// The current organization's logo, or — until it has one — a badge with
/// its initials in its own color. Never HydroTrack's.
class OrganizationLogo extends ConsumerWidget {
  const OrganizationLogo({super.key, this.size = 56});

  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logo = ref.watch(organizationLogoProvider).valueOrNull;
    final organization = ref.watch(currentOrganizationProvider);
    if (logo == null) {
      return organization == null
          ? SizedBox.square(dimension: size)
          : OrganizationBadge(organization: organization, size: size);
    }
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(AppRadius.panel),
      ),
      child: Image.memory(logo, fit: BoxFit.contain),
    );
  }
}

/// [organization]'s initials on its brand color — the stand-in for a logo
/// (also used in the organization list, where logos aren't downloaded).
class OrganizationBadge extends StatelessWidget {
  const OrganizationBadge({
    super.key,
    required this.organization,
    this.size = 36,
    this.enabled = true,
  });

  final Organization organization;
  final double size;
  final bool enabled;

  /// Initials take this share of the badge.
  static const _textScale = 0.4;

  @override
  Widget build(BuildContext context) {
    final palette = organization.palette;
    final background = enabled ? palette.primary : AppColors.border;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.panel),
      ),
      child: Text(
        organization.initials,
        style: TextStyle(
          color: BrandPalette.textOn(background),
          fontWeight: FontWeight.w700,
          fontSize: size * _textScale,
        ),
      ),
    );
  }
}
