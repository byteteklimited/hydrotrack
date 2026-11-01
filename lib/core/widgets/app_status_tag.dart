import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';

/// A small flat label for a record's non-default state — inactive
/// staff, a voided sale — wherever that state needs to stay visible
/// next to the record rather than hiding it. One shared widget so every
/// such tag looks and behaves identically.
class AppStatusTag extends StatelessWidget {
  const AppStatusTag({super.key, required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.input),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
