import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_error_state.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../../auth/data/models/staff_user.dart';
import '../../../auth/data/providers/auth_providers.dart';
import '../../data/models/customer.dart';
import '../../data/models/ledger_entry.dart';
import '../../data/providers/debts_providers.dart';
import '../widgets/add_opening_balance_dialog.dart';
import '../widgets/credit_limit_bar.dart';
import '../widgets/debt_ledger_section.dart';
import '../widgets/edit_credit_limit_dialog.dart';
import '../widgets/record_payment_sheet.dart';
import '../widgets/write_off_dialog.dart';

/// Wider than the usual 720 detail-screen cap — the ledger's
/// tablet/desktop table needs more room than a text-only detail screen
/// does, same reasoning as "Record sale" needing more width than a
/// single-column form once it grew a product table.
const double _contentCap = 900;

/// Balance vs credit limit, phone, and the full ledger for one customer.
class CustomerDetailScreen extends ConsumerWidget {
  const CustomerDetailScreen({super.key, required this.customerId});

  final String customerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customersAsync = ref.watch(customersProvider);

    return customersAsync.when(
      data: (customers) {
        final customer = customers.firstWhere((c) => c.id == customerId);
        return _CustomerDetailBody(customer: customer);
      },
      loading: () => const Scaffold(body: AppLoading()),
      error: (error, stackTrace) => Scaffold(
        appBar: AppBar(),
        body: AppErrorState(
          message:
              "Couldn't load this customer. Check your connection and try again.",
          onRetry: () => ref.invalidate(customersProvider),
        ),
      ),
    );
  }
}

class _CustomerDetailBody extends ConsumerWidget {
  const _CustomerDetailBody({required this.customer});

  final Customer customer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final ledgerAsync = ref.watch(customerLedgerProvider(customer.id));
    final isAdmin = ref.watch(authStateProvider)?.role.isAdminLevel ?? false;

    return Scaffold(
      appBar: AppBar(title: Text(customer.name)),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final horizontalPadding = constraints.maxWidth > _contentCap
              ? (constraints.maxWidth - _contentCap) / 2
              : AppSpacing.lg;

          return RefreshIndicator(
            onRefresh: () => Future.wait([
              ref.refresh(customersProvider.future),
              ref.refresh(customerLedgerProvider(customer.id).future),
            ]),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                AppSpacing.lg,
                horizontalPadding,
                AppSpacing.xxl,
              ),
              children: [
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      InkWell(
                        onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Calling comes with device integration in a later step.',
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.call_outlined,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Text(
                              customer.phone,
                              style: theme.textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      CreditLimitBar(
                        balance: customer.balance,
                        creditLimit: customer.creditLimit,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: AppButton(
                        label: 'Record payment',
                        onPressed: () =>
                            showRecordPaymentSheet(context, customer),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: AppButton(
                        label: 'Edit credit limit',
                        variant: AppButtonVariant.secondary,
                        onPressed: () =>
                            showEditCreditLimitDialog(context, customer),
                      ),
                    ),
                  ],
                ),
                if (isAdmin) ...[
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      Expanded(
                        child: AppButton(
                          label: 'Opening balance',
                          variant: AppButtonVariant.secondary,
                          onPressed: () =>
                              showAddOpeningBalanceDialog(context, customer),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: AppButton(
                          label: 'Write off',
                          variant: AppButtonVariant.secondary,
                          onPressed: () =>
                              showWriteOffDialog(context, customer),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: AppSpacing.xl),
                Text('Ledger', style: theme.textTheme.titleMedium),
                const SizedBox(height: AppSpacing.sm),
                ledgerAsync.when(
                  data: (entries) {
                    if (entries.isEmpty) {
                      return const AppEmptyState(
                        icon: Icons.receipt_long_outlined,
                        title: 'No transactions',
                        message:
                            'No transactions recorded yet for this customer.',
                      );
                    }
                    return DebtLedgerSection(
                      entries: ledgerWithRunningBalances(entries),
                    );
                  },
                  loading: () => const AppLoadingCompact(),
                  error: (error, stackTrace) => AppErrorState(
                    message:
                        "Couldn't load this customer's ledger. Check your connection and try again.",
                    onRetry: () =>
                        ref.invalidate(customerLedgerProvider(customer.id)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
