import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/action_error.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../data/models/worker.dart';
import '../../data/providers/payroll_providers.dart';
import 'pay_tab_list.dart';

/// Mark who came on the chosen day. Opens with the day's marks; unmarked
/// workers start as present.
class AttendanceTab extends ConsumerWidget {
  const AttendanceTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workers = ref.watch(activeWorkersProvider);
    final marksAsync = ref.watch(attendanceForDayProvider);
    final day = ref.watch(payDayProvider);
    final marks = marksAsync.valueOrNull;

    return PayTabList(
      withDay: true,
      children: [
        if (workers.isEmpty)
          const Text(
            'No workers yet. An owner or admin adds them under the Workers '
            'tab.',
          )
        else if (marks == null)
          marksAsync.hasError
              ? Text(
                  readableErrorMessage(marksAsync.error) ??
                      "Couldn't load attendance. Check your connection.",
                )
              : const AppLoading()
        else
          _AttendanceForm(
            key: ValueKey(day),
            day: day,
            workers: workers,
            marks: {for (final mark in marks) mark.workerId: mark.status},
          ),
      ],
    );
  }
}

class _AttendanceForm extends ConsumerStatefulWidget {
  const _AttendanceForm({
    super.key,
    required this.day,
    required this.workers,
    required this.marks,
  });

  final DateTime day;
  final List<Worker> workers;
  final Map<String, AttendanceStatus> marks;

  @override
  ConsumerState<_AttendanceForm> createState() => _AttendanceFormState();
}

class _AttendanceFormState extends ConsumerState<_AttendanceForm> {
  late final Map<String, AttendanceStatus> _marks = {
    for (final worker in widget.workers)
      worker.id: widget.marks[worker.id] ?? AttendanceStatus.present,
  };

  Future<void> _save() async {
    final saved = await ref
        .read(payrollActionControllerProvider.notifier)
        .recordAttendance(widget.day, _marks);
    if (!mounted) return;
    if (!saved) {
      showActionErrorSnackBar(
        context,
        message: readableErrorMessage(
          ref.read(payrollActionControllerProvider).error,
        ),
      );
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Attendance saved')));
  }

  @override
  Widget build(BuildContext context) {
    final busy = ref.watch(payrollActionControllerProvider).isLoading;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final worker in widget.workers)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  worker.name,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: AppSpacing.xs),
                SegmentedButton<AttendanceStatus>(
                  segments: [
                    for (final status in AttendanceStatus.values)
                      ButtonSegment(value: status, label: Text(status.label)),
                  ],
                  selected: {_marks[worker.id]!},
                  showSelectedIcon: false,
                  onSelectionChanged: (selection) =>
                      setState(() => _marks[worker.id] = selection.single),
                ),
              ],
            ),
          ),
        AppButton(
          label: widget.marks.isEmpty ? 'Save attendance' : 'Update attendance',
          isLoading: busy,
          onPressed: busy ? null : _save,
        ),
      ],
    );
  }
}
