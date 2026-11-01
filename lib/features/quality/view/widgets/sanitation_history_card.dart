import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_status_tag.dart';
import '../../data/models/sanitation.dart';
import '../../data/providers/quality_providers.dart';

/// One line per day for the last two weeks: done, done with items
/// missed (and which), or not done at all.
class SanitationHistoryCard extends StatelessWidget {
  const SanitationHistoryCard({
    super.key,
    required this.items,
    required this.checks,
  });

  final List<SanitationItem> items;
  final List<SanitationCheck> checks;

  static (String, Color) _tag(SanitationDayStatus status) => switch (status) {
    SanitationDayStatus.complete => ('Done', AppColors.successFg),
    SanitationDayStatus.issues => ('Items missed', AppColors.warningFg),
    SanitationDayStatus.notDone => ('Not done', AppColors.dangerFg),
  };

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final names = {for (final item in items) item.id: item.name};
    final secondary = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary);

    return AppCard(
      title: 'Last two weeks',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var back = 0; back < qualityHistoryDays; back++)
            Builder(
              builder: (context) {
                final day = DateTime(today.year, today.month, today.day - back);
                final dayChecks = checks
                    .where(
                      (check) =>
                          check.date.year == day.year &&
                          check.date.month == day.month &&
                          check.date.day == day.day,
                    )
                    .toList();
                final (label, color) = _tag(
                  sanitationDayStatus(items, dayChecks),
                );
                final missed = dayChecks
                    .where((check) => !check.done)
                    .map((check) => names[check.itemId] ?? 'Removed item');
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(DateFormat('EEE d MMM').format(day)),
                          ),
                          AppStatusTag(label: label, color: color),
                        ],
                      ),
                      if (missed.isNotEmpty)
                        Text('Missed: ${missed.join(', ')}', style: secondary),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
