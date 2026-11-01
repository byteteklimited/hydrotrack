import 'package:flutter_test/flutter_test.dart';
import 'package:hydrotrack/features/reports/data/models/report_summary.dart';

void main() {
  group('ProfitReportSection.profit', () {
    test('is revenue minus expenses', () {
      const section = ProfitReportSection(
        revenue: 500000,
        expenses: 120000,
        previousProfit: 300000,
      );
      expect(section.profit, 380000);
    });

    test('can be negative when expenses exceed revenue', () {
      const section = ProfitReportSection(
        revenue: 50000,
        expenses: 80000,
        previousProfit: 0,
      );
      expect(section.profit, -30000);
    });
  });
}
