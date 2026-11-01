import 'package:flutter_test/flutter_test.dart';
import 'package:hydrotrack/features/organizations/data/models/business_header.dart';
import 'package:hydrotrack/features/payroll/data/models/payroll.dart';
import 'package:hydrotrack/features/payroll/data/models/worker.dart';
import 'package:hydrotrack/features/payroll/view/widgets/payslip_pdf.dart';

Map<String, dynamic> _line(Map<String, dynamic> overrides) => {
  'id': 'l',
  'worker_id': 'w',
  'workers': {'name': 'Musa'},
  'pay_type': 'monthly',
  'rate': 54000,
  'days_present': 0,
  'days_absent': 2.5,
  'bags': 0,
  'gross': 54000,
  'absence_deduction': 5000,
  'advances': 10000,
  'adjustment': 0,
  'adjustment_note': null,
  'net': 39000,
  ...overrides,
};

void main() {
  test('pay types and attendance read their database values', () {
    expect(PayType.fromDb('per_bag'), PayType.perBag);
    expect(PayType.perBag.dbValue, 'per_bag');
    expect(AttendanceStatus.fromDb('half_day'), AttendanceStatus.halfDay);
  });

  test('a payroll totals its lines and spots a line below zero', () {
    final payroll = Payroll.fromJson({
      'id': 'p',
      'month': '2026-10-01',
      'status': 'draft',
      'working_days': 27,
      'payroll_lines': [
        _line({}),
        _line({
          'id': 'l2',
          'workers': {'name': 'Bello'},
          'pay_type': 'per_bag',
          'net': -9000,
        }),
      ],
    });
    expect(payroll.lines.first.workerName, 'Bello', reason: 'sorted by name');
    expect(payroll.totalNet, 30000);
    expect(payroll.hasNegativeLine, isTrue);
    expect(payroll.isPaid, isFalse);
  });

  test('payslip rows show how pay was worked out', () {
    final line = PayrollLine.fromJson(
      _line({'adjustment': 2000, 'adjustment_note': 'Bonus'}),
    );
    expect(payslipRows(line), [
      ('Monthly salary', '₦54,000'),
      ('Absent 2.5 days', '- ₦5,000'),
      ('Advances', '- ₦10,000'),
      ('Bonus', '+ ₦2,000'),
    ]);
    final daily = PayrollLine.fromJson(
      _line({
        'pay_type': 'daily',
        'rate': 3000,
        'days_present': 20.5,
        'gross': 61500,
        'absence_deduction': 0,
        'advances': 0,
      }),
    );
    expect(payslipRows(daily).single.$1, '20.5 days × ₦3,000');
  });

  test('a payslip PDF builds', () async {
    final payroll = Payroll.fromJson({
      'id': 'p',
      'month': '2026-10-01',
      'status': 'paid',
      'working_days': 27,
      'paid_at': '2026-11-01T10:00:00Z',
      'payroll_lines': [_line({})],
    });
    final doc = await buildPayslipPdf(
      payroll.lines.single,
      payroll,
      header: const BusinessHeader(name: 'Sunny Water', lines: []),
    );
    expect(await doc.save(), isNotEmpty);
  });
}
