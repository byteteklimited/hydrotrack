import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/action_error.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_status_tag.dart';
import '../../data/models/cash_count.dart';
import '../../data/providers/cash_count_providers.dart';

/// Finance, for managers and up: today's cash counts, short/over, and
/// Confirm once the cash is checked. Hidden when there are none.
class CashCountsCard extends ConsumerWidget {
  const CashCountsCard({super.key});

  Future<void> _confirm(
    BuildContext context,
    WidgetRef ref,
    CashCount count,
  ) async {
    final done = await ref
        .read(cashCountControllerProvider.notifier)
        .confirm(count.id);
    if (!context.mounted || done) return;
    showActionErrorSnackBar(
      context,
      message: readableErrorMessage(
        ref.read(cashCountControllerProvider).error,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final counts = ref.watch(todaysCashCountsProvider).valueOrNull ?? const [];
    if (counts.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: AppCard(
        title: "Today's cash counts",
        child: Column(
          children: [
            for (final count in counts)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            count.cashierName,
                            style: theme.textTheme.titleSmall,
                          ),
                          Text(
                            '${DateFormat.jm().format(count.countedAt.toLocal())} · '
                            'counted ${formatNaira(count.counted)} of '
                            '${formatNaira(count.expected)}'
                            '${count.note == null ? '' : ' · ${count.note}'}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (count.difference != 0)
                      AppStatusTag(
                        label: count.isShort
                            ? 'Short ${formatNaira(-count.difference)}'
                            : 'Over ${formatNaira(count.difference)}',
                        color: count.isShort
                            ? AppColors.moneyOut
                            : AppColors.lowStockWarning,
                      ),
                    if (count.isConfirmed)
                      const Padding(
                        padding: EdgeInsets.only(left: AppSpacing.sm),
                        child: Icon(
                          Icons.verified_outlined,
                          color: AppColors.moneyIn,
                        ),
                      )
                    else
                      AppButton(
                        label: 'Confirm',
                        variant: AppButtonVariant.text,
                        onPressed: () => _confirm(context, ref, count),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
