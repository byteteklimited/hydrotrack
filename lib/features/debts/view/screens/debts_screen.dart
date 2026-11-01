import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_breakpoints.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_error_state.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../../../core/widgets/app_modal.dart';
import '../../../../core/widgets/app_stat.dart';
import '../../data/models/customer.dart';
import '../../data/providers/debts_providers.dart';
import '../widgets/customer_picker_sheet.dart';
import '../widgets/debt_customer_section.dart';
import '../widgets/record_payment_sheet.dart';
import 'customer_detail_screen.dart';

/// Same reasoning as every other list screen in the app: content reads
/// best at a bounded width, implemented as responsive padding so
/// `RefreshIndicator`/`ListView` keep their native scroll behavior.
const double _contentCap = 900;

/// Debts: total owed first, then who owes it — overdue and biggest
/// balances first, customers in credit (overpaid) called out
/// separately from "settled", which stays collapsed at the bottom since
/// there's genuinely nothing to act on there.
///
/// "Record payment" is the primary action here, not "Add customer" —
/// recording a payment is the everyday task; onboarding a new customer
/// is rare and now lives in its own directory (More → Customers), with
/// its own "Add customer" FAB there instead.
class DebtsScreen extends ConsumerWidget {
  const DebtsScreen({super.key});

  Future<void> _recordPayment(BuildContext context, WidgetRef ref) async {
    final customers = ref.read(customersProvider).valueOrNull ?? [];
    final picked = await showCustomerPickerSheet(context, customers);
    if (picked != null && context.mounted) {
      await showRecordPaymentSheet(context, picked);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(debtsSummaryProvider);
    final customersAsync = ref.watch(customersProvider);

    return LayoutBuilder(
      builder: (context, outerConstraints) {
        // Same rule as Sales/Production: on a wide screen "Record
        // payment" moves into the header instead of floating.
        final isWide = AppBreakpoints.isMediumOrWider(
          outerConstraints.maxWidth,
        );
        final recordButton = AppButton(
          label: 'Record payment',
          leadingIcon: Icons.payments_outlined,
          onPressed: () => _recordPayment(context, ref),
        );

        return Scaffold(
          appBar: AppBar(
            title: const Text('Debts'),
            actions: [
              if (isWide)
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.lg),
                  child: recordButton,
                ),
            ],
          ),
          floatingActionButton: isWide ? null : recordButton,
          body: customersAsync.when(
            data: (customers) =>
                _DebtsBody(customers: customers, summaryAsync: summaryAsync),
            loading: () =>
                const AppLoading(message: 'Loading customer balances…'),
            error: (error, stackTrace) => AppErrorState(
              message:
                  "Couldn't load customer balances. Check your connection and try again.",
              onRetry: () => ref.invalidate(customersProvider),
            ),
          ),
        );
      },
    );
  }
}

class _DebtsBody extends ConsumerWidget {
  const _DebtsBody({required this.customers, required this.summaryAsync});

  final List<Customer> customers;
  final AsyncValue<DebtsSummary> summaryAsync;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final owing = customers.where((c) => c.balance > 0).toList()
      ..sort((a, b) {
        final aOverdue = a.isOverdue;
        final bOverdue = b.isOverdue;
        if (aOverdue != bOverdue) return aOverdue ? -1 : 1;
        return b.balance.compareTo(a.balance);
      });
    final inCredit = customers.where((c) => c.isInCredit).toList()
      ..sort((a, b) => a.balance.compareTo(b.balance));
    final settled = customers.where((c) => c.balance == 0).toList();

    void openCustomer(Customer customer) {
      showAppModal(
        context,
        builder: (_) => CustomerDetailScreen(customerId: customer.id),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalPadding = constraints.maxWidth > _contentCap
            ? (constraints.maxWidth - _contentCap) / 2
            : AppSpacing.lg;

        return RefreshIndicator(
          onRefresh: () => ref.refresh(customersProvider.future),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              AppSpacing.lg,
              horizontalPadding,
              AppSpacing.xxl,
            ),
            children: [
              switch (summaryAsync) {
                AsyncData(:final value) => _MoneyOutsideCard(value: value),
                _ => const SizedBox.shrink(),
              },
              const SizedBox(height: AppSpacing.lg),
              if (owing.isEmpty)
                const AppEmptyState(
                  icon: Icons.check_circle_outline,
                  title: 'No outstanding balances',
                  message: 'Every customer is paid up.',
                )
              else
                AppCard(
                  child: DebtCustomerSection(
                    customers: owing,
                    onTap: openCustomer,
                  ),
                ),
              if (inCredit.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Customer credit',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'These customers have paid more than they currently owe — '
                  'water or a refund is owed back to them.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                AppCard(
                  child: DebtCustomerSection(
                    customers: inCredit,
                    onTap: openCustomer,
                  ),
                ),
              ],
              if (settled.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                AppCard(
                  child: ExpansionTile(
                    title: Text(
                      'Settled (${settled.length})',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    tilePadding: EdgeInsets.zero,
                    childrenPadding: EdgeInsets.zero,
                    children: [
                      DebtCustomerSection(
                        customers: settled,
                        onTap: openCustomer,
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// "Money outside" is only red once something is genuinely overdue —
/// a healthy book of current, not-yet-due credit sales stays neutral
/// even though the figure itself is never zero. Mirrors the Dashboard's
/// own "Money outside" card exactly (`DashboardDebtCard`), which this
/// screen's own summary had drifted from.
class _MoneyOutsideCard extends StatelessWidget {
  const _MoneyOutsideCard({required this.value});

  final DebtsSummary value;

  @override
  Widget build(BuildContext context) {
    final hasOverdue = value.overdueCount > 0;
    return Column(
      children: [
        AppCard(
          accentColor: hasOverdue ? AppColors.moneyOut : null,
          child: AppStat(
            label: 'Money outside',
            value: formatNaira(value.totalOutside),
            valueColor: hasOverdue ? AppColors.moneyOut : null,
            qualifier: hasOverdue
                ? 'across ${value.customersOwing} customers, ${value.overdueCount} overdue'
                : 'across ${value.customersOwing} customers, all current',
          ),
        ),
        // Only shown when it's genuinely non-zero — a "₦0 customer
        // credit" card would just be noise on a normal day.
        if (value.customersInCredit > 0) ...[
          const SizedBox(height: AppSpacing.md),
          AppCard(
            child: AppStat(
              label: 'Customer credit',
              value: formatNaira(value.totalCredit),
              qualifier:
                  'owed back to ${value.customersInCredit} '
                  '${value.customersInCredit == 1 ? 'customer' : 'customers'}',
            ),
          ),
        ],
      ],
    );
  }
}
