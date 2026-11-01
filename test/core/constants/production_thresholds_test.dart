import 'package:flutter_test/flutter_test.dart';
import 'package:hydrotrack/core/constants/production_thresholds.dart';
import 'package:hydrotrack/core/theme/app_colors.dart';

void main() {
  group('wastageColor', () {
    test('is neutral (null) below the amber threshold', () {
      expect(wastageColor(0), isNull);
      expect(wastageColor(ProductionThresholds.wastageAmberPercent), isNull);
    });

    test('is amber once past the amber threshold but at/below red', () {
      expect(
        wastageColor(ProductionThresholds.wastageAmberPercent + 0.1),
        AppColors.lowStockWarning,
      );
      expect(
        wastageColor(ProductionThresholds.wastageRedPercent),
        AppColors.lowStockWarning,
      );
    });

    test('is red once past the red threshold', () {
      expect(
        wastageColor(ProductionThresholds.wastageRedPercent + 0.1),
        AppColors.moneyOut,
      );
    });
  });
}
