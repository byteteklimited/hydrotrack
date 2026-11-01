import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/action_error.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_error_state.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../../../core/widgets/app_modal.dart';
import '../../../../core/widgets/app_status_tag.dart';
import '../../../production/data/models/production_run.dart';
import '../../data/models/water_test.dart';
import '../../data/providers/quality_providers.dart';
import '../screens/record_water_test_screen.dart';
import 'quality_tab_list.dart';
import 'water_test_tile.dart';

/// Today's shifts (tested or not) and the last two weeks of water tests.
class WaterTestsTab extends ConsumerWidget {
  const WaterTestsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final testsAsync = ref.watch(waterTestsProvider);
    return QualityTabList(
      onRefresh: () => ref.refresh(waterTestsProvider.future),
      children: [
        AppButton(
          label: 'Record water test',
          leadingIcon: Icons.science_outlined,
          onPressed: () => showAppModal<void>(
            context,
            builder: (_) => const RecordWaterTestScreen(),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        testsAsync.when(
          loading: () => const AppLoading(message: 'Loading water tests…'),
          error: (error, stackTrace) => AppErrorState(
            message:
                readableErrorMessage(error) ??
                "Couldn't load water tests. Check your connection and try "
                    'again.',
            onRetry: () => ref.invalidate(waterTestsProvider),
          ),
          data: (tests) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _TodayCard(tests: tests),
              const SizedBox(height: AppSpacing.lg),
              if (tests.isEmpty)
                const Text(
                  'No water tests in the last two weeks. Test the water at '
                  'the start of each shift and record the readings here.',
                ),
              for (final test in tests) WaterTestTile(test: test),
            ],
          ),
        ),
      ],
    );
  }
}

class _TodayCard extends StatelessWidget {
  const _TodayCard({required this.tests});

  final List<WaterTest> tests;

  static (String, Color) _tag(ShiftTestStatus status) => switch (status) {
    ShiftTestStatus.passed => ('Passed', AppColors.successFg),
    ShiftTestStatus.failed => ('Failed', AppColors.dangerFg),
    ShiftTestStatus.notTested => ('Not tested', AppColors.warningFg),
  };

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    return AppCard(
      title: 'Today',
      child: Column(
        children: [
          for (final shift in ProductionShift.values)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: Row(
                children: [
                  Expanded(child: Text('${shift.label} shift')),
                  Builder(
                    builder: (context) {
                      final (label, color) = _tag(
                        shiftTestStatus(tests, today, shift),
                      );
                      return AppStatusTag(label: label, color: color);
                    },
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
