import 'package:supabase_flutter/supabase_flutter.dart';

/// Limits a query to [column] on or after [from] and before [to]. Lists
/// load a day, a month or a recent window rather than whole tables (the
/// server returns at most 1,000 rows per request).
extension QueryRange<T> on PostgrestFilterBuilder<T> {
  PostgrestFilterBuilder<T> inRange(
    String column, {
    DateTime? from,
    DateTime? to,
    bool dateOnly = false,
  }) {
    String value(DateTime moment) => dateOnly
        ? moment.toIso8601String().split('T').first
        : moment.toUtc().toIso8601String();
    var query = this;
    if (from != null) query = query.gte(column, value(from));
    if (to != null) query = query.lt(column, value(to));
    return query;
  }
}
