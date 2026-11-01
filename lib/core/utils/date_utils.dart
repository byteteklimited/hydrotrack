import 'package:intl/intl.dart';

/// Strips the time-of-day off a [DateTime], for grouping and same-day
/// comparisons.
DateTime dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

bool isSameDay(DateTime a, DateTime b) => dateOnly(a) == dateOnly(b);

/// "Today", "Yesterday", or a short date — for grouping records by day.
String formatRelativeDay(DateTime date) {
  final diff = dateOnly(DateTime.now()).difference(dateOnly(date)).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  return DateFormat('EEE, d MMM').format(date);
}

/// A full date and time, e.g. `23 Oct 2026, 4:18 pm` — for a single
/// precise timestamp (a receipt, an audit-trail entry), as opposed to
/// [formatRelativeDay]'s day-grouping use.
String formatDateTime(DateTime dateTime) {
  return DateFormat(
    'd MMM yyyy, h:mm a',
  ).format(dateTime).replaceAll('AM', 'am').replaceAll('PM', 'pm');
}

/// "Just now", "5 minutes ago", "2 hours ago", or a short date once it's
/// more than a day old — for an activity feed, where exactly how long ago
/// something happened matters more than its calendar date.
String formatRelativeTime(DateTime dateTime) {
  final diff = DateTime.now().difference(dateTime);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) {
    final m = diff.inMinutes;
    return '$m minute${m == 1 ? '' : 's'} ago';
  }
  if (diff.inHours < 24) {
    final h = diff.inHours;
    return '$h hour${h == 1 ? '' : 's'} ago';
  }
  if (diff.inDays < 7) {
    final d = diff.inDays;
    return '$d day${d == 1 ? '' : 's'} ago';
  }
  return DateFormat('d MMM yyyy').format(dateTime);
}

/// True when [moment] is on or after [from] and before [to] (either may be
/// open-ended). For filtering the device's own data like the server does.
bool isInRange(DateTime moment, {DateTime? from, DateTime? to}) =>
    (from == null || !moment.isBefore(from)) &&
    (to == null || moment.isBefore(to));

/// The start of the day after [day].
DateTime nextDay(DateTime day) => DateTime(day.year, day.month, day.day + 1);

/// Lists with a "Show earlier" button load this window of history.
class HistoryWindow {
  HistoryWindow._();

  static const initialDays = 30;
  static const stepDays = 30;

  /// The first day shown when [days] days are loaded.
  static DateTime since(int days) =>
      dateOnly(DateTime.now()).subtract(Duration(days: days - 1));
}
