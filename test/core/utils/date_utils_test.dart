import 'package:flutter_test/flutter_test.dart';
import 'package:hydrotrack/core/utils/date_utils.dart';

void main() {
  group('dateOnly', () {
    test('strips the time of day', () {
      final result = dateOnly(DateTime(2026, 3, 5, 14, 32, 10));
      expect(result, DateTime(2026, 3, 5));
    });
  });

  group('isSameDay', () {
    test('true for the same date at different times', () {
      expect(
        isSameDay(DateTime(2026, 3, 5, 1), DateTime(2026, 3, 5, 23)),
        isTrue,
      );
    });

    test('false for different dates', () {
      expect(isSameDay(DateTime(2026, 3, 5), DateTime(2026, 3, 6)), isFalse);
    });
  });

  group('formatRelativeDay', () {
    test('returns "Today" for the current date', () {
      expect(formatRelativeDay(DateTime.now()), 'Today');
    });

    test('returns "Yesterday" for one day ago', () {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      expect(formatRelativeDay(yesterday), 'Yesterday');
    });

    test('returns a short date for anything older', () {
      final lastWeek = DateTime.now().subtract(const Duration(days: 8));
      final result = formatRelativeDay(lastWeek);
      expect(result, isNot('Today'));
      expect(result, isNot('Yesterday'));
    });
  });
}
