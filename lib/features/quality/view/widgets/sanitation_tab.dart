import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/action_error.dart';
import '../../../../core/widgets/app_error_state.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../data/models/sanitation.dart';
import '../../data/providers/quality_providers.dart';
import 'quality_tab_list.dart';
import 'sanitation_history_card.dart';
import 'today_checklist_card.dart';

/// Today's sanitation checklist, and how the last two weeks went.
class SanitationTab extends ConsumerWidget {
  const SanitationTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(sanitationItemsProvider);
    final checksAsync = ref.watch(sanitationChecksProvider);

    Future<void> refresh() async {
      ref
        ..invalidate(sanitationItemsProvider)
        ..invalidate(sanitationChecksProvider);
      await ref.read(sanitationChecksProvider.future);
    }

    final error = itemsAsync.error ?? checksAsync.error;
    final items = itemsAsync.valueOrNull;
    final checks = checksAsync.valueOrNull;

    return QualityTabList(
      onRefresh: refresh,
      children: [
        if (error != null)
          AppErrorState(
            message:
                readableErrorMessage(error) ??
                "Couldn't load the checklist. Check your connection and try "
                    'again.',
            onRetry: refresh,
          )
        else if (items == null || checks == null)
          const AppLoading(message: 'Loading the checklist…')
        else ...[
          TodayChecklistCard(
            items: items.where((item) => item.isActive).toList(),
            todaysChecks: _onDay(checks, DateTime.now()),
          ),
          const SizedBox(height: AppSpacing.lg),
          SanitationHistoryCard(items: items, checks: checks),
        ],
      ],
    );
  }

  static List<SanitationCheck> _onDay(
    List<SanitationCheck> checks,
    DateTime day,
  ) => checks
      .where(
        (check) =>
            check.date.year == day.year &&
            check.date.month == day.month &&
            check.date.day == day.day,
      )
      .toList();
}
