import 'package:flutter_test/flutter_test.dart';
import 'package:hydrotrack/core/utils/date_utils.dart';

void main() {
  group('isInRange', () {
    final noon = DateTime(2026, 11, 1, 12);

    test('from is inclusive, to is exclusive', () {
      expect(isInRange(noon, from: noon), isTrue);
      expect(isInRange(noon, to: noon), isFalse);
      expect(
        isInRange(noon, from: DateTime(2026, 11, 1), to: DateTime(2026, 11, 2)),
        isTrue,
      );
    });

    test('open ends include everything on that side', () {
      expect(isInRange(noon), isTrue);
      expect(isInRange(noon, from: DateTime(2027)), isFalse);
    });
  });

  test('nextDay crosses month ends', () {
    expect(nextDay(DateTime(2026, 1, 31)), DateTime(2026, 2, 1));
  });

  test('HistoryWindow covers exactly the last N days, today included', () {
    final today = dateOnly(DateTime.now());
    expect(HistoryWindow.since(1), today);
    expect(
      HistoryWindow.since(HistoryWindow.initialDays),
      today.subtract(const Duration(days: HistoryWindow.initialDays - 1)),
    );
  });
}
