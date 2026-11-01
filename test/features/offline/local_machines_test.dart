import 'package:flutter_test/flutter_test.dart';
import 'package:hydrotrack/features/expenses/data/models/expense.dart';
import 'package:hydrotrack/features/machines/data/models/machine.dart';
import 'package:hydrotrack/features/offline/data/models/offline_snapshot.dart';
import 'package:hydrotrack/features/offline/data/models/outbox_operation.dart';
import 'package:hydrotrack/features/offline/data/services/local_bookkeeping.dart';

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
  recordedAt: DateTime.utc(2026, 11, 1, 9),
  payload: payload,
);

OfflineSnapshot _withMachines() {
  final s = sampleSnapshot();
  s.rows('machines').addAll([
    {'id': 'gen', 'name': 'Generator', 'kind': 'generator', 'is_active': true},
    {'id': 'm1', 'name': 'Machine 1', 'kind': 'production', 'is_active': true},
  ]);
  return s;
}

void main() {
  test('diesel logged offline posts its expense and cash out', () {
    final s = _withMachines();
    LocalBookkeeping.apply(
      s,
      _op(OperationType.diesel, {
        'machine_id': 'gen',
        'date': '2026-11-01',
        'litres': 50,
        'cost': 45000,
        'method': 'cash',
        'run_hours': null,
        'note': null,
      }),
    );
    expect(s.rows('diesel_logs').single['litres'], 50);
    final expense = Expense.fromJson(s.rows('expenses').single);
    expect(expense.amount, 45000);
    expect(expense.description, 'Diesel for Generator: 50 litres');
    expect(s.cashInHand, 5000);
  });

  test('maintenance done offline restarts the task and posts any cost', () {
    final s = _withMachines();
    s.rows('maintenance_tasks').add({
      'id': 'task',
      'machine_id': 'm1',
      'name': 'Change filter',
      'every_days': 30,
      'last_done_on': '2026-09-01',
      'created_at': '2026-08-01T00:00:00Z',
      'is_active': true,
    });
    LocalBookkeeping.apply(
      s,
      _op(OperationType.maintenanceDone, {
        'task_id': 'task',
        'done_on': '2026-11-01',
        'cost': 0,
        'method': 'cash',
        'note': null,
      }),
    );
    final task = MaintenanceTask.fromJson(s.row('maintenance_tasks', 'task')!);
    expect(task.dueOn, DateTime(2026, 12, 1));
    expect(s.rows('expenses'), isEmpty, reason: 'no cost, no expense');
  });

  test('a breakdown reported and fixed offline keeps the repair cost', () {
    final s = _withMachines();
    LocalBookkeeping.apply(
      s,
      _op(OperationType.breakdown, {
        'id': 'bd',
        'machine_id': 'm1',
        'started_at': '2026-11-01T07:00:00Z',
        'cause': 'Belt',
      }),
    );
    LocalBookkeeping.apply(
      s,
      _op(OperationType.breakdownEnd, {
        'breakdown_id': 'bd',
        'ended_at': '2026-11-01T09:00:00Z',
        'repair_cost': 5000,
        'method': 'transfer',
        'note': null,
      }, id: 'op-2'),
    );
    final breakdown = Breakdown.fromJson(s.row('breakdowns', 'bd')!);
    expect(breakdown.isOpen, isFalse);
    expect(breakdown.repairCost, 5000);
    expect(
      Expense.fromJson(s.rows('expenses').single).description,
      'Repair: Machine 1 (Belt)',
    );
  });

  test('a run made offline is linked to its machine by name', () {
    final s = _withMachines();
    LocalBookkeeping.apply(
      s,
      _op(OperationType.productionRun, {
        'date': '2026-11-01',
        'shift': 'morning',
        'machine': 'machine 1',
        'operator_name': 'Ade',
        'product_id': sachetProductId,
        'quantity_produced': 100,
        'wastage': 0,
      }),
    );
    expect(s.rows('production_runs').single['machine_id'], 'm1');
  });
}
