import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_error_state.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../../../core/widgets/app_stat.dart';
import '../../../../core/widgets/responsive_center.dart';
import '../../../auth/data/models/staff_user.dart';
import '../../../auth/data/providers/auth_providers.dart';
import '../../data/models/supplier.dart';
import '../../data/providers/purchases_providers.dart';
import '../widgets/pay_supplier_dialog.dart';

/// A supplier's account: what we owe, every purchase and payment, and Pay
/// (Owner/Admin/Manager).
class SupplierDetailScreen extends ConsumerWidget {
  const SupplierDetailScreen({super.key, required this.supplierId});

  final String supplierId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final supplier =
        (ref.watch(suppliersProvider).valueOrNull ?? const <Supplier>[])
            .where((s) => s.id == supplierId)
            .firstOrNull;
    final ledgerAsync = ref.watch(supplierLedgerProvider(supplierId));
    final canPay = ref.watch(authStateProvider)?.role.canManage ?? false;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(supplier?.name ?? 'Supplier')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          ResponsiveCenter(
            maxWidth: 720,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (supplier != null)
                  AppCard(
                    child: Row(
                      children: [
                        Expanded(
                          child: AppStat(
                            label: 'We owe',
                            value: formatNaira(supplier.balance),
                          ),
                        ),
                        if (canPay && supplier.balance > 0)
                          AppButton(
                            label: 'Pay supplier',
                            onPressed: () =>
                                showPaySupplierDialog(context, supplier),
                          ),
                      ],
                    ),
                  ),
                const SizedBox(height: AppSpacing.md),
                ledgerAsync.when(
                  loading: () => const AppLoading(),
                  error: (error, stackTrace) => AppErrorState(
                    message:
                        "Couldn't load this account. Check your connection and try again.",
                    onRetry: () =>
                        ref.invalidate(supplierLedgerProvider(supplierId)),
                  ),
                  data: (entries) => AppCard(
                    title: 'Account',
                    child: Column(
                      children: [
                        if (entries.isEmpty) const Text('Nothing yet.'),
                        for (final entry in entries)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              entry.isPayment ? 'Payment' : 'Purchase',
                            ),
                            subtitle: Text(
                              '${DateFormat.yMMMd().format(entry.date)}'
                              '${entry.note == null ? '' : ' · ${entry.note}'}',
                            ),
                            trailing: Text(
                              '${entry.isPayment ? '−' : '+'}${formatNaira(entry.amount)}',
                              style: theme.textTheme.titleSmall?.copyWith(
                                color: entry.isPayment
                                    ? AppColors.moneyIn
                                    : AppColors.textPrimary,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
