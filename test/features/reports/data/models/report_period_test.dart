import 'package:flutter_test/flutter_test.dart';
import 'package:hydrotrack/features/reports/data/models/report_period.dart';

void main() {
  group('ReportPeriod.today', () {
    test('start and end are both today', () {
      final period = ReportPeriod.today();
      expect(period.start, period.end);
      expect(period.contains(DateTime.now()), isTrue);
    });

    test('previous is yesterday', () {
      final period = ReportPeriod.today();
      final previous = period.previous;
      expect(previous.start, period.start.subtract(const Duration(days: 1)));
      expect(previous.end, previous.start);
    });
  });

  group('ReportPeriod.thisWeek', () {
    test('starts on Monday', () {
      final period = ReportPeriod.thisWeek();
      expect(period.start.weekday, DateTime.monday);
    });

    test('previous is the 7 days immediately before this week started', () {
      final period = ReportPeriod.thisWeek();
      final previous = period.previous;
      expect(previous.end, period.start.subtract(const Duration(days: 1)));
      expect(previous.start, period.start.subtract(const Duration(days: 7)));
    });
  });

  group('ReportPeriod.thisMonth', () {
    test('starts on the 1st of the current month', () {
      final period = ReportPeriod.thisMonth();
      expect(period.start.day, 1);
    });

    test(
      'previous is last month, same length of coverage up to the last day',
      () {
        final period = ReportPeriod(
          type: ReportPeriodType.thisMonth,
          start: DateTime(2026, 3, 1),
          end: DateTime(2026, 3, 15),
        );
        final previous = period.previous;
        expect(previous.start, DateTime(2026, 2, 1));
        expect(previous.end, DateTime(2026, 2, 28));
      },
    );

    test('handles January correctly by rolling back into December', () {
      final period = ReportPeriod(
        type: ReportPeriodType.thisMonth,
        start: DateTime(2026, 1, 1),
        end: DateTime(2026, 1, 10),
      );
      final previous = period.previous;
      expect(previous.start, DateTime(2025, 12, 1));
      expect(previous.end, DateTime(2025, 12, 31));
    });
  });

  group('ReportPeriod.custom', () {
    test('previous is an equal-length window immediately before', () {
      final period = ReportPeriod.custom(
        DateTime(2026, 3, 10),
        DateTime(2026, 3, 12),
      );
      final previous = period.previous;
      expect(previous.end, DateTime(2026, 3, 9));
      expect(previous.start, DateTime(2026, 3, 7));
    });
  });

  group('contains', () {
    test('true for a date inside the range, inclusive of both ends', () {
      final period = ReportPeriod.custom(
        DateTime(2026, 3, 1),
        DateTime(2026, 3, 31),
      );
      expect(period.contains(DateTime(2026, 3, 1)), isTrue);
      expect(period.contains(DateTime(2026, 3, 31, 23, 59)), isTrue);
      expect(period.contains(DateTime(2026, 3, 15)), isTrue);
    });

    test('false for a date outside the range', () {
      final period = ReportPeriod.custom(
        DateTime(2026, 3, 1),
        DateTime(2026, 3, 31),
      );
      expect(period.contains(DateTime(2026, 2, 28)), isFalse);
      expect(period.contains(DateTime(2026, 4, 1)), isFalse);
    });
  });

  group('label / comparisonLabel', () {
    test('every period type has both labels', () {
      for (final period in [
        ReportPeriod.today(),
        ReportPeriod.thisWeek(),
        ReportPeriod.thisMonth(),
        ReportPeriod.custom(DateTime(2026, 1, 1), DateTime(2026, 1, 5)),
      ]) {
        expect(period.label, isNotEmpty);
        expect(period.comparisonLabel, isNotEmpty);
      }
    });
  });
}
