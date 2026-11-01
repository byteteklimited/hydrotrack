import 'package:flutter/material.dart';

import '../../../../core/theme/app_brand.dart';
import '../../../../core/theme/app_breakpoints.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/responsive_center.dart';

/// Shared page shell for every signed-out screen (sign in, create
/// account, join with invite): white page, logo, title and subtitle, then
/// the form — a plain scrolling column on phones, centered and capped at
/// 420px from tablet width up.
class AuthPageLayout extends StatelessWidget {
  const AuthPageLayout({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.showBack = false,
  });

  final String title;
  final String subtitle;
  final Widget child;

  /// Shows a back arrow (for screens reached from Sign in).
  final bool showBack;

  static const _maxFormWidth = 420.0;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(child: Image.asset(AppBrand.logo, height: 56)),
        const SizedBox(height: AppSpacing.xl),
        Text(
          title,
          textAlign: TextAlign.center,
          style: textTheme.headlineMedium,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.xxl),
        child,
      ],
    );

    return Scaffold(
      backgroundColor: AppColors.surfaceWhite,
      appBar: showBack ? AppBar(backgroundColor: AppColors.surfaceWhite) : null,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (!AppBreakpoints.isMediumOrWider(constraints.maxWidth)) {
              return SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: content,
              );
            }
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Center(
                  child: ResponsiveCenter(
                    maxWidth: _maxFormWidth,
                    child: content,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
