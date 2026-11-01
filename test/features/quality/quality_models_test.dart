import 'package:flutter_test/flutter_test.dart';
import 'package:hydrotrack/features/organizations/data/models/organization.dart';
import 'package:hydrotrack/features/organizations/data/models/water_limits.dart';
import 'package:hydrotrack/features/production/data/models/production_run.dart';
import 'package:hydrotrack/features/quality/data/models/batch_trace.dart';
import 'package:hydrotrack/features/quality/data/models/permit.dart';
import 'package:hydrotrack/features/quality/data/models/sanitation.dart';
import 'package:hydrotrack/features/quality/data/models/water_test.dart';
import 'package:hydrotrack/features/quality/view/widgets/permit_tile.dart';
import 'package:hydrotrack/features/sales/data/models/sale.dart';

WaterTest _test(String shift, bool passed, int hour) => WaterTest.fromJson({
  'id': 't-$shift-$hour',
  'date': '2026-11-01',
  'shift': shift,
  'tested_at': DateTime(2026, 11, 1, hour).toUtc().toIso8601String(),
  'ph': 7,
  'tds': 100,
  'chlorine': 0.2,
  'passed': passed,
  'problems': <String>[],
  'profiles': {'full_name': 'Sam Store'},
});

void main() {
  group('WaterLimits', () {
    const limits = WaterLimits();

    test('defaults are NIS 554 and good water passes', () {
      expect(limits.problems(ph: 7.2, tds: 120, chlorine: 0.22), isEmpty);
    });

    test('failures are worded exactly as the server words them', () {
      expect(limits.problems(ph: 9.1, tds: 650, chlorine: 0.22), [
        'pH 9.1 (allowed 6.5–8.5)',
        'TDS 650 mg/L (max 500)',
      ]);
      expect(limits.problems(ph: 7, tds: 10, chlorine: 0.5), [
        'chlorine 0.5 mg/L (allowed 0.2–0.25)',
      ]);
    });

    test('an organization reads its own limits', () {
      final organization = Organization.fromJson({
        'id': 'org',
        'name': 'Sunny Water',
        'water_tds_max': 700,
      });
      expect(organization.waterLimits.tdsMax, 700);
      expect(organization.waterLimits.phMin, 6.5);
      expect(organization.toJson()['water_tds_max'], 700);
    });
  });

  test("a shift's status is its latest test", () {
    final day = DateTime(2026, 11, 1);
    final tests = [_test('morning', false, 7), _test('morning', true, 9)];
    expect(
      shiftTestStatus(tests, day, ProductionShift.morning),
      ShiftTestStatus.passed,
    );
    expect(
      shiftTestStatus(tests, day, ProductionShift.afternoon),
      ShiftTestStatus.notTested,
    );
  });

  test('a checklist day is done, has items missed, or was not done', () {
    const items = [
      SanitationItem(id: 'a', name: 'Floor', position: 1, isActive: true),
      SanitationItem(id: 'b', name: 'Tanks', position: 2, isActive: true),
      SanitationItem(id: 'c', name: 'Old', position: 3, isActive: false),
    ];
    SanitationCheck check(String item, bool done) => SanitationCheck(
      date: DateTime(2026, 11, 1),
      itemId: item,
      done: done,
      checkedBy: 'Sam',
    );
    expect(sanitationDayStatus(items, []), SanitationDayStatus.notDone);
    expect(
      sanitationDayStatus(items, [check('a', true), check('b', true)]),
      SanitationDayStatus.complete,
      reason: 'stopped items are not asked',
    );
    expect(
      sanitationDayStatus(items, [check('a', true), check('b', false)]),
      SanitationDayStatus.issues,
    );
  });

  test('permits count days left and are flagged as expiry nears', () {
    final permit = Permit(
      id: 'p',
      name: 'NAFDAC licence',
      expiresOn: DateTime(2026, 12, 1),
    );
    expect(permit.daysLeft(DateTime(2026, 11, 1, 18)), 30);
    expect(PermitTile.tag(45).$1, '45 days left');
    expect(PermitTile.tag(0).$1, 'Expires today');
    expect(PermitTile.tag(-3).$1, 'Expired');
  });

  test('a batch trace reads the server result', () {
    final trace = BatchTrace.fromJson({
      'run': {
        'batch_number': '261101-M-2',
        'date': '2026-11-01',
        'shift': 'morning',
        'machine': 'Machine 1',
        'product': '50cl Sachet',
        'quantity_produced': 10,
      },
      'bags_in_stock': 5,
      'water_tests': [
        {'passed': true},
        {'passed': false},
      ],
      'sales': [
        {
          'id': 's1',
          'date_time': '2026-11-01T10:00:00Z',
          'customer_name': 'Musa Stores',
          'customer_phone': '0803',
          'bags': 5,
          'voided': false,
          'driver_name': null,
        },
        {
          'id': 's2',
          'date_time': '2026-11-01T11:00:00Z',
          'bags': 2,
          'voided': true,
        },
      ],
    });
    expect(trace.waterTestsPassed, isFalse);
    expect(trace.bagsSold, 5, reason: 'voided sales are not counted');
    expect(trace.sales.first.customerName, 'Musa Stores');
  });

  test('sales and runs carry batch numbers', () {
    final sale = Sale.fromJson({
      'id': 's',
      'date_time': '2026-11-01T10:00:00Z',
      'customer_type': 'walk_in',
      'sale_lines': <Map<String, dynamic>>[],
      'total': 0,
      'amount_paid': 0,
      'payment_method': 'cash',
      'balance': 0,
      'batch_numbers': ['261101-M-1'],
    });
    expect(sale.batchNumbers, ['261101-M-1']);
  });
}
