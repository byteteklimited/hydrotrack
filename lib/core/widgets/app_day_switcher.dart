import 'package:flutter/material.dart';

import '../utils/date_utils.dart';

/// Moves a day-scoped list backward/forward — back up to [earliestDaysBack]
/// days, forward no further than today. The caller owns the actual day
/// state; this widget just renders it and reports changes.
class AppDaySwitcher extends StatelessWidget {
  const AppDaySwitcher({
    super.key,
    required this.day,
    required this.onChanged,
    this.earliestDaysBack = 30,
  });

  final DateTime day;
  final ValueChanged<DateTime> onChanged;
  final int earliestDaysBack;

  @override
  Widget build(BuildContext context) {
    final today = dateOnly(DateTime.now());
    final earliest = today.subtract(Duration(days: earliestDaysBack));
    final canGoBack = day.isAfter(earliest);
    final canGoForward = day.isBefore(today);

    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          tooltip: 'Previous day',
          onPressed: canGoBack
              ? () => onChanged(day.subtract(const Duration(days: 1)))
              : null,
        ),
        Expanded(
          child: Text(
            formatRelativeDay(day),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          tooltip: 'Next day',
          onPressed: canGoForward
              ? () => onChanged(day.add(const Duration(days: 1)))
              : null,
        ),
      ],
    );
  }
}
