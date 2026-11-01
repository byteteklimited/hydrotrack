import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Moves a month-scoped view backward/forward — back up to [monthsBack]
/// months, forward no further than the current month. The caller owns
/// the month (its first day); this widget renders it and reports changes.
class AppMonthSwitcher extends StatelessWidget {
  const AppMonthSwitcher({
    super.key,
    required this.month,
    required this.onChanged,
    this.monthsBack = 6,
  });

  final DateTime month;
  final ValueChanged<DateTime> onChanged;
  final int monthsBack;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final currentMonth = DateTime(now.year, now.month);
    final earliest = DateTime(
      currentMonth.year,
      currentMonth.month - monthsBack,
    );
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          tooltip: 'Previous month',
          onPressed: month.isAfter(earliest)
              ? () => onChanged(DateTime(month.year, month.month - 1))
              : null,
        ),
        Expanded(
          child: Text(
            DateFormat('MMMM yyyy').format(month),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          tooltip: 'Next month',
          onPressed: month.isBefore(currentMonth)
              ? () => onChanged(DateTime(month.year, month.month + 1))
              : null,
        ),
      ],
    );
  }
}
