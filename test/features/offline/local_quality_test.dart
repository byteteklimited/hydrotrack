import 'package:flutter_test/flutter_test.dart';
import 'package:hydrotrack/features/offline/data/models/outbox_operation.dart';
import 'package:hydrotrack/features/offline/data/services/local_bookkeeping.dart';
import 'package:hydrotrack/features/quality/data/models/sanitation.dart';
import 'package:hydrotrack/features/quality/data/models/water_test.dart';
import 'package:hydrotrack/features/sales/data/models/sale.dart';

import 'offline_fixtures.dart';

OutboxOperation _op(
  OperationType type,
  Map<String, dynamic> payload, {
  String id = 'op-1',
}) => OutboxOperation(
  opId: id,
  seq: 1,
  type: type,
  actorId: cashierId,
  actorName: 'Sam Store',
  recordedAt: DateTime.utc(2026, 11, 1, 7, 30),
  payload: payload,
);

void main() {
  test('a water test made offline is checked against the limits', () {
    final s = sampleSnapshot();
    s.organization['water_tds_max'] = 300;
    LocalBookkeeping.apply(
      s,
      _op(OperationType.waterTest, {
        'date': '2026-11-01',
        'shift': 'morning',
        'ph': 7.1,
        'tds': 350,
        'chlorine': 0.21,
        'note': null,
      }),
    );
    final test = WaterTest.fromJson(s.rows('water_tests').single);
    expect(test.passed, isFalse);
    expect(test.problems, ['TDS 350 mg/L (max 300)']);
    expect(test.recordedBy, 'Sam Store');
  });

  test('filling the checklist again the same day replaces the ticks', () {
    final s = sampleSnapshot();
    Map<String, dynamic> payload(bool done) => {
      'date': '2026-11-01',
      'items': [
        {'item_id': 'floor', 'done': done, 'note': done ? null : 'No mop'},
      ],
    };
    LocalBookkeeping.apply(
      s,
      _op(OperationType.sanitationCheck, payload(false)),
    );
    LocalBookkeeping.apply(
      s,
      _op(OperationType.sanitationCheck, payload(true), id: 'op-2'),
    );
    final check = SanitationCheck.fromJson(s.rows('sanitation_checks').single);
    expect(check.done, isTrue);
    expect(check.note, isNull);
  });

  test('a sale made offline notes the batch its bags came from', () {
    final s = sampleSnapshot();
    s.rows('production_runs').add({
      'id': 'run-1',
      'batch_number': '261001-M-1',
    });
    s.row('stock_batches', 'batch-old')!['production_run_id'] = 'run-1';
    LocalBookkeeping.apply(s, _op(OperationType.sale, salePayload(bags: 5)));
    expect(Sale.fromJson(s.row('sales', 'op-1')!).batchNumbers, ['261001-M-1']);
  });
}
