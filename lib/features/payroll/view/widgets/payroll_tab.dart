import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/action_error.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_inline_alert.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../../../core/widgets/app_month_switcher.dart';
import '../../data/models/payroll.dart';
import '../../data/providers/payroll_providers.dart';
import 'pay_tab_list.dart';
import 'payroll_dialogs.dart';
import 'payroll_line_tile.dart';

/// The month's payroll (owners and admins): prepare it, adjust lines,
/// pay it, and share payslips.
class PayrollTab extends ConsumerWidget {
  const PayrollTab({super.key});

  Future<void> _prepare(BuildContext context, WidgetRef ref) async {
    final done = await ref
        .read(payrollActionControllerProvider.notifier)
        .preparePayroll(ref.read(payrollMonthProvider));
    if (!done && context.mounted) {
      showActionErrorSnackBar(
        context,
        message: readableErrorMessage(
          ref.read(payrollActionControllerProvider).error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(payrollMonthProvider);
    final payrollAsync = ref.watch(payrollProvider);
    final busy = ref.watch(payrollActionControllerProvider).isLoading;
    final monthName = DateFormat('MMMM yyyy').format(month);

    return PayTabList(
      children: [
        AppMonthSwitcher(
          month: month,
          monthsBack: 12,
          onChanged: (value) =>
              ref.read(payrollMonthProvider.notifier).state = value,
        ),
        const SizedBox(height: AppSpacing.md),
        payrollAsync.when(
          loading: () => const AppLoading(),
          error: (error, stackTrace) => Text(
            readableErrorMessage(error) ??
                "Couldn't load the payroll. Check your connection.",
          ),
          data: (payroll) => payroll == null
              ? AppCard(
                  title: 'No payroll for $monthName yet',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Mark attendance and bag counts first, then prepare '
                        "the payroll: it works out everyone's pay from them, "
                        'less advances.',
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppButton(
                        label: 'Prepare payroll',
                        isLoading: busy,
                        onPressed: busy ? null : () => _prepare(context, ref),
                      ),
                    ],
                  ),
                )
              : _PayrollView(
                  payroll: payroll,
                  onRecalculate: () => _prepare(context, ref),
                ),
        ),
      ],
    );
  }
}

class _PayrollView extends ConsumerWidget {
  const _PayrollView({required this.payroll, required this.onRecalculate});

  final Payroll payroll;
  final VoidCallback onRecalculate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final busy = ref.watch(payrollActionControllerProvider).isLoading;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          title: payroll.isPaid ? 'Paid' : 'Draft — not paid yet',
          accentColor: payroll.isPaid ? AppColors.successFg : null,
          child: Text(
            '${formatNaira(payroll.totalNet)} for ${payroll.lines.length} '
            'people · ${payroll.workingDays} working days'
            '${payroll.paidAt == null ? '' : ' · paid ${DateFormat('d MMM').format(payroll.paidAt!)}'}',
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        for (final line in payroll.lines)
          PayrollLineTile(line: line, payroll: payroll),
        if (!payroll.isPaid) ...[
          if (payroll.hasNegativeLine)
            const AppInlineAlert(
              severity: AppAlertSeverity.warning,
              message:
                  "Someone's advances are more than their pay. Adjust their "
                  'line before paying.',
            ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              AppButton(
                label: 'Pay everyone',
                leadingIcon: Icons.payments_outlined,
                onPressed: busy || payroll.hasNegativeLine
                    ? null
                    : () => showPayPayrollDialog(context, payroll),
              ),
              AppButton(
                label: 'Work it out again',
                variant: AppButtonVariant.secondary,
                leadingIcon: Icons.refresh,
                onPressed: busy ? null : onRecalculate,
              ),
            ],
          ),
        ],
      ],
    );
  }
}
