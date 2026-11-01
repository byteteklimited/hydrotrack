import 'package:flutter_test/flutter_test.dart';
import 'package:hydrotrack/features/machines/data/models/machine.dart';
import 'package:hydrotrack/features/machines/data/models/machine_report.dart';
import 'package:hydrotrack/features/machines/view/widgets/maintenance_due_card.dart';

void main() {
  MaintenanceTask task({String? lastDone}) => MaintenanceTask.fromJson({
    'id': 't',
    'machine_id': 'm',
    'name': 'Change filter',
    'every_days': 30,
    'last_done_on': lastDone,
    'created_at': '2026-10-01T09:00:00Z',
    'is_active': true,
  });

  test('a task is due every N days from when it was last done', () {
    expect(task().dueOn, DateTime(2026, 10, 31), reason: 'from creation');
    expect(task(lastDone: '2026-10-20').dueOn, DateTime(2026, 11, 19));
    final today = DateTime(2026, 11, 21, 15);
    expect(task(lastDone: '2026-10-20').daysUntilDue(today), -2);
    expect(
      MaintenanceDueCard.dueText(task(lastDone: '2026-10-20'), today),
      'Overdue since 19 Nov',
    );
    expect(
      MaintenanceDueCard.dueText(task(lastDone: '2026-10-22'), today),
      'Due today',
    );
    expect(
      MaintenanceDueCard.dueText(task(lastDone: '2026-10-23'), today),
      'Due tomorrow',
    );
  });

  test('downtime is counted to one decimal hour, open ones up to now', () {
    final breakdown = Breakdown.fromJson({
      'id': 'b',
      'machine_id': 'm',
      'started_at': '2026-11-01T08:00:00Z',
      'ended_at': null,
      'cause': 'Belt',
    });
    expect(breakdown.isOpen, isTrue);
    expect(breakdown.downtimeHours(DateTime.utc(2026, 11, 1, 10, 30)), 2.5);
  });

  test('unknown machine kinds read as other', () {
    expect(MachineKind.fromDb('bottling'), MachineKind.other);
    expect(MachineKind.fromDb('generator'), MachineKind.generator);
  });

  test('the machine report reads per machine figures and diesel per bag', () {
    final report = MachineReport.fromJson({
      'machines': [
        {
          'machine_id': 'm1',
          'name': 'Machine 1',
          'kind': 'production',
          'bags': 400,
          'downtime_hours': 1.5,
          'breakdowns': 1,
          'repair_cost': 0,
          'maintenance_cost': 0,
          'litres': 0,
          'diesel_cost': 0,
          'run_hours': 0,
        },
        {
          'machine_id': 'm2',
          'name': 'Machine 2',
          'kind': 'production',
          'bags': 100,
          'downtime_hours': 2.5,
          'breakdowns': 1,
          'repair_cost': 0,
          'maintenance_cost': 0,
          'litres': 0,
          'diesel_cost': 0,
          'run_hours': 0,
        },
      ],
      'bags': 500,
      'litres': 20,
      'diesel_cost': 20000,
      'litres_per_100_bags': 4,
      'diesel_cost_per_bag': 40,
    });
    expect(report.downtimeHours, 4);
    expect(report.forMachine('m2')?.bags, 100);
    expect(report.dieselCostPerBag, 40);
  });
}
