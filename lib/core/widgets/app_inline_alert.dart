import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/brand_palette.dart';

/// Meaning of an [AppInlineAlert] — picks its color and icon. Ties
/// directly to the app's color rules: red is destructive/failure only,
/// amber is a threshold warning, green is a confirmed positive outcome,
/// and [info] is this app's existing neutral "info" accent (see
/// [AppCard]'s own doc comment) — for a helpful prompt that isn't a
/// warning about anything, just new/empty state guidance.
enum AppAlertSeverity { error, warning, success, info }

/// The app's one inline alert: a quiet, non-blocking banner that sits in
/// the flow of a form or screen instead of interrupting it. This is the
/// standard way to surface a recoverable error (failed sign-in, failed
/// save) everywhere in the app — never a dialog, which both current
/// UI/UX guidance and this app's "keep it calm" rule treat as reserved
/// for choices the user must make, not messages they must read.
class AppInlineAlert extends StatelessWidget {
  const AppInlineAlert({
    super.key,
    required this.message,
    this.severity = AppAlertSeverity.error,
  });

  final String message;
  final AppAlertSeverity severity;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (color, icon) = switch (severity) {
      AppAlertSeverity.error => (AppColors.moneyOut, Icons.error_outline),
      AppAlertSeverity.warning => (
        AppColors.lowStockWarning,
        Icons.warning_amber_outlined,
      ),
      AppAlertSeverity.success => (
        AppColors.moneyIn,
        Icons.check_circle_outline,
      ),
      AppAlertSeverity.info => (context.brand.primaryText, Icons.info_outline),
    };
    // Info's background is the brand's own cyan tint, not a generic
    // 10%-of-the-foreground-color blend the other three severities use —
    // navy at 10% isn't the same color as the brand's actual info wash.
    final background = severity == AppAlertSeverity.info
        ? context.brand.accentTint
        : color.withValues(alpha: 0.1);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.input),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}
