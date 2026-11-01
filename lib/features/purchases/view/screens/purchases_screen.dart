import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/action_error.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_error_state.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../../../core/widgets/app_modal.dart';
import '../../../../core/widgets/responsive_center.dart';
import '../../../../core/widgets/show_earlier_button.dart';
import '../../data/providers/purchases_providers.dart';
import '../widgets/purchase_tile.dart';
import '../widgets/suppliers_card.dart';
import 'record_purchase_screen.dart';

/// Raw materials bought, suppliers and what we owe them.
class PurchasesScreen extends ConsumerWidget {
  const PurchasesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final purchasesAsync = ref.watch(purchasesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Purchases')),
      floatingActionButton: AppButton(
        label: 'Record purchase',
        leadingIcon: Icons.add,
        onPressed: () => showAppModal<void>(
          context,
          builder: (_) => const RecordPurchaseScreen(),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref
            ..invalidate(suppliersProvider)
            ..invalidate(purchasesProvider);
          await ref.read(purchasesProvider.future);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.xxl * 2,
          ),
          children: [
            ResponsiveCenter(
              maxWidth: 720,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SuppliersCard(),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'Purchases',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  purchasesAsync.when(
                    loading: () =>
                        const AppLoading(message: 'Loading purchases…'),
                    error: (error, stackTrace) => AppErrorState(
                      message:
                          readableErrorMessage(error) ??
                          "Couldn't load purchases. Check your connection and try again.",
                      onRetry: () => ref.invalidate(purchasesProvider),
                    ),
                    data: (purchases) => Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (purchases.isEmpty)
                          const Text(
                            'No purchases in this period. Record one when '
                            'materials are delivered: stock and costs update '
                            'automatically.',
                          ),
                        for (final purchase in purchases)
                          PurchaseTile(purchase: purchase),
                        ShowEarlierButton(
                          days: ref.watch(purchaseHistoryDaysProvider),
                          onPressed: () =>
                              ref
                                  .read(purchaseHistoryDaysProvider.notifier)
                                  .state += HistoryWindow
                                  .stepDays,
                        ),
                      ],
                    ),
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
