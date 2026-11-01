import '../../../production/data/models/production_run.dart';

/// One water test (pH, TDS, residual chlorine) for a production shift,
/// checked against the organization's limits when it was recorded.
class WaterTest {
  const WaterTest({
    required this.id,
    required this.date,
    required this.shift,
    required this.testedAt,
    required this.ph,
    required this.tds,
    required this.chlorine,
    required this.passed,
    required this.recordedBy,
    this.problems = const [],
    this.note,
  });

  final String id;
  final DateTime date;
  final ProductionShift shift;
  final DateTime testedAt;
  final num ph;

  /// mg/L
  final num tds;

  /// Residual chlorine, mg/L.
  final num chlorine;
  final bool passed;

  /// Why it failed, e.g. "pH 9.1 (allowed 6.5–8.5)".
  final List<String> problems;
  final String? note;
  final String recordedBy;

  factory WaterTest.fromJson(Map<String, dynamic> json) => WaterTest(
    id: json['id'] as String,
    date: DateTime.parse(json['date'] as String),
    shift: ProductionShift.values.byName(json['shift'] as String),
    testedAt: DateTime.parse(json['tested_at'] as String).toLocal(),
    ph: json['ph'] as num,
    tds: json['tds'] as num,
    chlorine: json['chlorine'] as num,
    passed: json['passed'] as bool,
    problems: [
      for (final problem in json['problems'] as List? ?? const [])
        problem as String,
    ],
    note: json['note'] as String?,
    recordedBy:
        (json['profiles'] as Map<String, dynamic>?)?['full_name'] as String? ??
        'Unknown',
  );
}

/// Where a shift stands today: passed, failed (latest test), or untested.
enum ShiftTestStatus { passed, failed, notTested }

/// The latest test's result for [shift] on [day], from [tests].
ShiftTestStatus shiftTestStatus(
  List<WaterTest> tests,
  DateTime day,
  ProductionShift shift,
) {
  final latest =
      tests
          .where(
            (test) =>
                test.shift == shift &&
                test.date.year == day.year &&
                test.date.month == day.month &&
                test.date.day == day.day,
          )
          .toList()
        ..sort((a, b) => b.testedAt.compareTo(a.testedAt));
  if (latest.isEmpty) return ShiftTestStatus.notTested;
  return latest.first.passed ? ShiftTestStatus.passed : ShiftTestStatus.failed;
}
