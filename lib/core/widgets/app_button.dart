import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';

/// Visual role of an [AppButton]. Styling for each comes from the button
/// themes wired in Step 2 — this widget only picks the variant. [text] is
/// the lowest-emphasis case — a dialog's "Cancel", an inline "+ Add new
/// X" link — anywhere a bordered [secondary] would be too heavy.
enum AppButtonVariant { primary, secondary, destructive, text }

/// The app's one button widget. Every form action — save, confirm, delete —
/// goes through this so loading and disabled states behave the same way
/// everywhere.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.leadingIcon,
    this.isLoading = false,
    this.expanded = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final IconData? leadingIcon;
  final bool isLoading;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final effectiveOnPressed = isLoading ? null : onPressed;
    final child = _buildChild(_foregroundColor(scheme));

    final button = switch (variant) {
      AppButtonVariant.primary => FilledButton(
        onPressed: effectiveOnPressed,
        child: child,
      ),
      AppButtonVariant.secondary => OutlinedButton(
        onPressed: effectiveOnPressed,
        child: child,
      ),
      AppButtonVariant.destructive => FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.error,
          foregroundColor: scheme.onError,
        ),
        onPressed: effectiveOnPressed,
        child: child,
      ),
      AppButtonVariant.text => TextButton(
        onPressed: effectiveOnPressed,
        child: child,
      ),
    };

    return expanded ? SizedBox(width: double.infinity, child: button) : button;
  }

  Color _foregroundColor(ColorScheme scheme) {
    return switch (variant) {
      AppButtonVariant.primary => scheme.onPrimary,
      AppButtonVariant.secondary => scheme.primary,
      AppButtonVariant.destructive => scheme.onError,
      AppButtonVariant.text => scheme.primary,
    };
  }

  Widget _buildChild(Color foreground) {
    if (isLoading) {
      return SizedBox(
        height: 20,
        width: 20,
        child: CircularProgressIndicator(strokeWidth: 2, color: foreground),
      );
    }
    if (leadingIcon != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(leadingIcon, size: 18),
          const SizedBox(width: AppSpacing.sm),
          Text(label),
        ],
      );
    }
    return Text(label);
  }
}
