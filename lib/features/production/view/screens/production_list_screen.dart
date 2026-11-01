import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_breakpoints.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_error_state.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../../../core/widgets/app_modal.dart';
import '../../../../core/widgets/show_earlier_button.dart';
import '../../../auth/data/models/staff_user.dart';
import '../../../auth/data/providers/auth_providers.dart';
import '../../data/models/production_run.dart';
import '../../data/providers/production_providers.dart';
import '../widgets/production_day_section.dart';
import '../widgets/production_today_card.dart';
import 'manage_recipes_screen.dart';
import 'production_run_detail_screen.dart';
import 'record_production_screen.dart';

/// A list screen's content reads best at a bounded width — this cap keeps
/// rows from stretching into a long label on one edge and a lonely value
/// on the other once the window gets wide, without needing to touch
/// `RefreshIndicator`/`ListView`'s own scroll behavior to do it.
const double _contentCap = 900;

/// Production leads with today's numbers, then every run grouped by day,
/// most recent first.
class ProductionListScreen extends ConsumerWidget {
  const ProductionListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final runsAsync = ref.watch(productionRunsProvider);
    final totalsAsync = ref.watch(todaysProductionTotalsProvider);
    final role = ref.watch(authStateProvider)?.role;
    final canManageRecipes = role?.canManage ?? false;

    return LayoutBuilder(
      builder: (context, outerConstraints) {
        // Same rule as Sales: on a wide screen "Record production" moves
        // into the header instead of floating, measured once here so it
        // can't disagree with the FAB about which width band it's in.
        final isWide = AppBreakpoints.isMediumOrWider(
          outerConstraints.maxWidth,
        );
        final recordButton = AppButton(
          label: 'Record production',
          leadingIcon: Icons.add,
          onPressed: () => showAppModal(
            context,
            builder: (_) => const RecordProductionScreen(),
          ),
        );

        return Scaffold(
          appBar: AppBar(
            title: const Text('Production'),
            actions: [
              if (canManageRecipes)
                IconButton(
                  icon: const Icon(Icons.science_outlined),
                  tooltip: 'Recipes — what each product uses to make a bag',
                  onPressed: () => showAppModal(
                    context,
                    builder: (_) => const ManageRecipesScreen(),
                  ),
                ),
              if (isWide)
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.lg),
                  child: recordButton,
                ),
            ],
          ),
          floatingActionButton: isWide ? null : recordButton,
          body: LayoutBuilder(
            builder: (context, constraints) {
              final horizontalPadding = constraints.maxWidth > _contentCap
                  ? (constraints.maxWidth - _contentCap) / 2
                  : AppSpacing.lg;

              return runsAsync.when(
                data: (runs) {
                  if (runs.isEmpty) {
                    return RefreshIndicator(
                      onRefresh: () =>
                          ref.refresh(productionRunsProvider.future),
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: const [
                          AppEmptyState(
                            icon: Icons.factory_outlined,
                            title: 'No production recorded today',
                            message: 'Record a production run to get started.',
                          ),
                        ],
                      ),
                    );
                  }
                  final grouped = _groupByDay(runs);
                  final totals = totalsAsync.valueOrNull;

                  return RefreshIndicator(
                    onRefresh: () => ref.refresh(productionRunsProvider.future),
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(
                        horizontalPadding,
                        AppSpacing.lg,
                        horizontalPadding,
                        AppSpacing.xxl,
                      ),
                      children: [
                        if (totals != null) ...[
                          ProductionTodayCard(totals: totals),
                          const SizedBox(height: AppSpacing.md),
                        ],
                        for (final day in grouped.keys) ...[
                          ProductionDaySection(
                            date: day,
                            runs: grouped[day]!,
                            onRunTap: (run) async {
                              final deleted = await showAppModal<bool>(
                                context,
                                builder: (_) =>
                                    ProductionRunDetailScreen(runId: run.id),
                              );
                              if (deleted == true && context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Production run deleted'),
                                  ),
                                );
                              }
                            },
                          ),
                          const SizedBox(height: AppSpacing.md),
                        ],
                        ShowEarlierButton(
                          days: ref.watch(productionHistoryDaysProvider),
                          onPressed: () =>
                              ref
                                  .read(productionHistoryDaysProvider.notifier)
                                  .state += HistoryWindow
                                  .stepDays,
                        ),
                      ],
                    ),
                  );
                },
                loading: () =>
                    const AppLoading(message: 'Loading production runs…'),
                error: (error, stackTrace) => AppErrorState(
                  message:
                      "Couldn't load production records. Check your connection and try again.",
                  onRetry: () => ref.invalidate(productionRunsProvider),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Map<DateTime, List<ProductionRun>> _groupByDay(List<ProductionRun> runs) {
    final map = <DateTime, List<ProductionRun>>{};
    for (final run in runs) {
      map.putIfAbsent(dateOnly(run.date), () => []).add(run);
    }
    final sortedDays = map.keys.toList()..sort((a, b) => b.compareTo(a));
    return {for (final day in sortedDays) day: map[day]!};
  }
}
