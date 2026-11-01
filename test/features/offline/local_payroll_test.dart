import 'package:flutter_test/flutter_test.dart';
import 'package:hydrotrack/features/offline/data/models/outbox_operation.dart';
import 'package:hydrotrack/features/offline/data/services/local_bookkeeping.dart';
import 'package:hydrotrack/features/payroll/data/models/worker.dart';

import 'offline_fixtures.dart';

OutboxOperation _op(
  OperationType type,
  Map<String, dynamic> payload,
  String id,
) => OutboxOperation(
  opId: id,
  seq: 1,
  type: type,
  actorId: cashierId,
  actorName: 'Sam Store',
  recordedAt: DateTime.utc(2026, 11, 1, 17),
  payload: payload,
);

void main() {
  test('attendance marked again offline replaces the day', () {
    final s = sampleSnapshot();
    Map<String, dynamic> payload(String status) => {
      'date': '2026-11-01',
      'entries': [
        {'worker_id': 'ada', 'status': status},
      ],
    };
    LocalBookkeeping.apply(
      s,
      _op(OperationType.attendance, payload('absent'), 'a'),
    );
    LocalBookkeeping.apply(
      s,
      _op(OperationType.attendance, payload('half_day'), 'b'),
    );
    final mark = AttendanceMark.fromJson(s.rows('attendance').single);
    expect(mark.status, AttendanceStatus.halfDay);
  });

  test('bag counts entered offline are kept per worker per day', () {
    final s = sampleSnapshot();
    LocalBookkeeping.apply(
      s,
      _op(OperationType.bagCounts, {
        'date': '2026-11-01',
        'entries': [
          {'worker_id': 'bello', 'bags': 900},
          {'worker_id': 'joy', 'bags': 750},
        ],
      }, 'c'),
    );
    expect(s.rows('bag_counts').map(BagCount.fromJson).map((c) => c.bags), [
      900,
      750,
    ]);
  });
}
