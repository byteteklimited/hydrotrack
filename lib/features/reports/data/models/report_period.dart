import 'package:intl/intl.dart';

import '../../../../core/utils/date_utils.dart';

/// Which preset (or custom range) a report is showing.
enum ReportPeriodType { today, thisWeek, thisMonth, custom }

/// A date range a report is scoped to, plus how to find the equivalent
/// period immediately before it for comparison.
class ReportPeriod {
  const ReportPeriod({
    required this.type,
    required this.start,
    required this.end,
  });

  final ReportPeriodType type;

  /// Date-only, inclusive.
  final DateTime start;

  /// Date-only, inclusive.
  final DateTime end;

  factory ReportPeriod.today() {
    final today = dateOnly(DateTime.now());
    return ReportPeriod(type: ReportPeriodType.today, start: today, end: today);
  }

  factory ReportPeriod.thisWeek() {
    final today = dateOnly(DateTime.now());
    final monday = today.subtract(Duration(days: today.weekday - 1));
    return ReportPeriod(
      type: ReportPeriodType.thisWeek,
      start: monday,
      end: today,
    );
  }

  factory ReportPeriod.thisMonth() {
    final today = dateOnly(DateTime.now());
    return ReportPeriod(
      type: ReportPeriodType.thisMonth,
      start: DateTime(today.year, today.month, 1),
      end: today,
    );
  }

  factory ReportPeriod.custom(DateTime start, DateTime end) {
    return ReportPeriod(
      type: ReportPeriodType.custom,
      start: dateOnly(start),
      end: dateOnly(end),
    );
  }

  /// The equivalent period immediately before this one — last week, last
  /// month, yesterday, or (for a custom range) an equal-length window
  /// right before it.
  ReportPeriod get previous {
    switch (type) {
      case ReportPeriodType.today:
        final yesterday = start.subtract(const Duration(days: 1));
        return ReportPeriod.custom(yesterday, yesterday);
      case ReportPeriodType.thisWeek:
        final prevMonday = start.subtract(const Duration(days: 7));
        final prevSunday = start.subtract(const Duration(days: 1));
        return ReportPeriod.custom(prevMonday, prevSunday);
      case ReportPeriodType.thisMonth:
        final lastDayOfPrevMonth = start.subtract(const Duration(days: 1));
        final firstDayOfPrevMonth = DateTime(
          lastDayOfPrevMonth.year,
          lastDayOfPrevMonth.month,
          1,
        );
        return ReportPeriod.custom(firstDayOfPrevMonth, lastDayOfPrevMonth);
      case ReportPeriodType.custom:
        final lengthInDays = end.difference(start).inDays;
        final prevEnd = start.subtract(const Duration(days: 1));
        final prevStart = prevEnd.subtract(Duration(days: lengthInDays));
        return ReportPeriod.custom(prevStart, prevEnd);
    }
  }

  String get label => switch (type) {
    ReportPeriodType.today => 'Today',
    ReportPeriodType.thisWeek => 'This week',
    ReportPeriodType.thisMonth => 'This month',
    ReportPeriodType.custom =>
      '${DateFormat('d MMM').format(start)} – ${DateFormat('d MMM').format(end)}',
  };

  /// Plain-language name for comparison lines ("last week", "yesterday").
  String get comparisonLabel => switch (type) {
    ReportPeriodType.today => 'yesterday',
    ReportPeriodType.thisWeek => 'last week',
    ReportPeriodType.thisMonth => 'last month',
    ReportPeriodType.custom => 'the previous period',
  };

  bool contains(DateTime dateTime) {
    final day = dateOnly(dateTime);
    return !day.isBefore(start) && !day.isAfter(end);
  }
}
