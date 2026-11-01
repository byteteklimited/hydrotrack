import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_status_tag.dart';
import '../../../organizations/data/models/water_limits.dart';
import '../../../production/data/models/production_run.dart';
import '../../data/models/water_test.dart';

/// One water test: shift, readings, and why it failed if it did.
class WaterTestTile extends StatelessWidget {
  const WaterTestTile({super.key, required this.test});

  final WaterTest test;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final secondary = theme.textTheme.bodySmall?.copyWith(
      color: AppColors.textSecondary,
    );
    String plain(num value) => WaterLimits.plain(value);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppCard(
        accentColor: test.passed ? null : AppColors.dangerFg,
        title:
            '${DateFormat('EEE d MMM').format(test.date)} · '
            '${test.shift.label}',
        trailing: AppStatusTag(
          label: test.passed ? 'Passed' : 'Failed',
          color: test.passed ? AppColors.successFg : AppColors.dangerFg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'pH ${plain(test.ph)} · TDS ${plain(test.tds)} mg/L · '
              'chlorine ${plain(test.chlorine)} mg/L',
            ),
            for (final problem in test.problems)
              Text(
                problem,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.dangerFg,
                ),
              ),
            if (test.note != null) Text(test.note!, style: secondary),
            Text(
              '${test.recordedBy} · ${DateFormat.jm().format(test.testedAt)}',
              style: secondary,
            ),
          ],
        ),
      ),
    );
  }
}
