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

  test('profit takes off what the bags sold cost, then expenses', () {
    const section = ProfitReportSection(
      revenue: 100000,
      costOfSales: 30000,
      expenses: 20000,
      previousProfit: 0,
    );
    expect(section.grossProfit, 70000);
    expect(section.profit, 50000);
  });
}
