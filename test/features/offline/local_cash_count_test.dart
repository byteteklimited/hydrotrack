import 'package:flutter_test/flutter_test.dart';
import 'package:hydrotrack/features/finance/data/models/cash_count.dart';
import 'package:hydrotrack/features/finance/data/repositories/cash_count_repository.dart';
import 'package:hydrotrack/features/offline/data/models/outbox_operation.dart';
import 'package:hydrotrack/features/offline/data/services/local_bookkeeping.dart';

import 'offline_fixtures.dart';

OutboxOperation _op(
  String id,
  OperationType type,
  Map<String, dynamic> payload,
  DateTime at, {
  String actor = cashierId,
}) => OutboxOperation(
  opId: id,
  seq: 1,
  type: type,
  actorId: actor,
  actorName: 'Carol Cashier',
  recordedAt: at,
  payload: payload,
);

void main() {
  final morning = DateTime.now().copyWith(hour: 9, minute: 0);

  test('expected cash follows the cashier\'s own cash sales offline', () {
    final s = sampleSnapshot();
    LocalBookkeeping.apply(
      s,
      _op('s1', OperationType.sale, salePayload(bags: 10), morning),
    );
    LocalBookkeeping.apply(
      s,
      _op(
        's2',
        OperationType.sale,
        salePayload(bags: 3),
        morning,
        actor: 'other',
      ),
    );
    final expected = localExpectedCash(
      s,
      cashierId,
      morning.add(const Duration(hours: 1)),
    );
    expect(expected.cashIn, 4000);
    expect(expected.expected, 4000);
  });

  test('a count made offline records the shortage, and the next starts '
      'after it', () {
    final s = sampleSnapshot();
    LocalBookkeeping.apply(
      s,
      _op('s1', OperationType.sale, salePayload(bags: 10), morning),
    );
    LocalBookkeeping.apply(
      s,
      _op('c1', OperationType.cashCount, {
        'counted': 3500,
        'note': 'Change',
      }, morning.add(const Duration(hours: 1))),
    );
    final count = CashCount.fromJson(s.row('cash_counts', 'c1')!);
    expect(count.expected, 4000);
    expect(count.difference, -500);

    LocalBookkeeping.apply(
      s,
      _op(
        's3',
        OperationType.sale,
        salePayload(bags: 1),
        morning.add(const Duration(hours: 2)),
      ),
    );
    expect(
      localExpectedCash(
        s,
        cashierId,
        morning.add(const Duration(hours: 3)),
      ).expected,
      400,
    );
  });
}
