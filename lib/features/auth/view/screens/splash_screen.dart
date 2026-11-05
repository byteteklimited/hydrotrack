import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_routes.dart';
import '../../../../core/theme/app_brand.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../offline/data/providers/offline_providers.dart';
import '../../../organizations/data/providers/organization_providers.dart';
import '../../data/providers/auth_providers.dart';
import '../../../../core/theme/brand_palette.dart';

/// Brief branded pause on launch, then routes to login — or, if a session
/// is already active, into the right organization.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateNext();
  }

  Future<void> _navigateNext() async {
    await Future.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;
    if (!ref.read(authRepositoryProvider).hasSession) {
      Navigator.of(context).pushReplacementNamed(AppRoutes.login);
      return;
    }
    try {
      await enterApp(context, ref);
    } catch (_) {
      // Couldn't load organizations (usually no connection): carry on
      // offline if this device holds their organization; otherwise the
      // picker shows the error with a retry.
      if (!mounted) return;
      if (await enterDeviceOrganization(context, ref)) return;
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed(AppRoutes.organizations);
    }
  }

  @override
  Widget build(BuildContext context) {
    // White, not brand blue — the logo itself is a light/white-glass
    // lockup with no separate dark-background variant provided, so a
    // colored background risks the lighter parts of the artwork
    // blending into it. White is also what Login already uses, so the
    // two screens read as one continuous brand moment rather than two
    // different treatments.
    return Scaffold(
      backgroundColor: AppColors.surfaceWhite,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(AppBrand.logo, width: AppBrand.splashWidth),
            const SizedBox(height: AppSpacing.xxl),
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: context.brand.primaryText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
