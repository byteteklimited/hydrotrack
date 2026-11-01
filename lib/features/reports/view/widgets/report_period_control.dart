import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/report_period.dart';
import '../../data/providers/reports_providers.dart';

/// Today / This week / This month / Custom range — switches which
/// period the report below is scoped to.
class ReportPeriodControl extends ConsumerWidget {
  const ReportPeriodControl({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(selectedReportPeriodProvider);

    Future<void> pickCustomRange() async {
      final now = DateTime.now();
      final picked = await showDateRangePicker(
        context: context,
        firstDate: now.subtract(const Duration(days: 365)),
        lastDate: now,
        initialDateRange: DateTimeRange(start: period.start, end: period.end),
      );
      if (picked != null) {
        ref.read(selectedReportPeriodProvider.notifier).state =
            ReportPeriod.custom(picked.start, picked.end);
      }
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SegmentedButton<ReportPeriodType>(
        segments: const [
          ButtonSegment(value: ReportPeriodType.today, label: Text('Today')),
          ButtonSegment(
            value: ReportPeriodType.thisWeek,
            label: Text('This week'),
          ),
          ButtonSegment(
            value: ReportPeriodType.thisMonth,
            label: Text('This month'),
          ),
          ButtonSegment(value: ReportPeriodType.custom, label: Text('Custom')),
        ],
        selected: {period.type},
        onSelectionChanged: (selection) {
          switch (selection.first) {
            case ReportPeriodType.today:
              ref.read(selectedReportPeriodProvider.notifier).state =
                  ReportPeriod.today();
            case ReportPeriodType.thisWeek:
              ref.read(selectedReportPeriodProvider.notifier).state =
                  ReportPeriod.thisWeek();
            case ReportPeriodType.thisMonth:
              ref.read(selectedReportPeriodProvider.notifier).state =
                  ReportPeriod.thisMonth();
            case ReportPeriodType.custom:
              pickCustomRange();
          }
        },
      ),
    );
  }
}
