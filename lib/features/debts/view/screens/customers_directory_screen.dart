import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_error_state.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../../../core/widgets/app_modal.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../data/models/customer.dart';
import '../../data/providers/debts_providers.dart';
import '../widgets/debt_customer_tile.dart';
import 'add_customer_screen.dart';
import 'customer_detail_screen.dart';

/// Same reasoning as every other list screen in the app.
const double _contentCap = 900;

/// Every customer, alphabetically — not "who owes money" (that's
/// Debts), just the directory itself: onboarding a new one, and finding
/// any customer regardless of their current balance.
class CustomersDirectoryScreen extends ConsumerStatefulWidget {
  const CustomersDirectoryScreen({super.key});

  @override
  ConsumerState<CustomersDirectoryScreen> createState() =>
      _CustomersDirectoryScreenState();
}

class _CustomersDirectoryScreenState
    extends ConsumerState<CustomersDirectoryScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(
      () => setState(() => _query = _searchController.text.toLowerCase()),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final customersAsync = ref.watch(customersProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Customers')),
      floatingActionButton: AppButton(
        label: 'Add customer',
        leadingIcon: Icons.person_add_outlined,
        onPressed: () async {
          final created = await showAppModal<Customer>(
            context,
            builder: (_) => const AddCustomerScreen(),
          );
          if (created == null || !context.mounted) return;

          // `createCustomer`'s own write already invalidates
          // `customersProvider`, but invalidation alone doesn't
          // guarantee the refetch has landed by the time the detail
          // screen below reads it — awaiting it here does, so it can
          // safely find `created.id` on its very first build instead
          // of racing it.
          ref.invalidate(customersProvider);
          await ref.read(customersProvider.future);
          if (!context.mounted) return;

          await showAppModal(
            context,
            builder: (_) => CustomerDetailScreen(customerId: created.id),
          );
        },
      ),
      body: customersAsync.when(
        data: (customers) {
          final sorted = [...customers]
            ..sort((a, b) => a.name.compareTo(b.name));
          final filtered = _query.isEmpty
              ? sorted
              : sorted
                    .where(
                      (c) =>
                          c.name.toLowerCase().contains(_query) ||
                          c.area.toLowerCase().contains(_query),
                    )
                    .toList();

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
                    AppTextField(
                      hint: 'e.g. Musa or Sabon Gari',
                      label: 'Search by name or area',
                      controller: _searchController,
                      prefixIcon: const Icon(Icons.search),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    if (customers.isEmpty)
                      const AppEmptyState(
                        icon: Icons.people_outline,
                        title: 'No customers yet',
                        message:
                            'No customers added yet. Tap + to add the first one.',
                      )
                    else if (filtered.isEmpty)
                      const AppEmptyState(
                        icon: Icons.search_off,
                        title: 'No matches',
                        message: 'No customer matches that search.',
                      )
                    else
                      AppCard(
                        child: Column(
                          children: [
                            for (var i = 0; i < filtered.length; i++) ...[
                              DebtCustomerTile(
                                customer: filtered[i],
                                onTap: () => showAppModal(
                                  context,
                                  builder: (_) => CustomerDetailScreen(
                                    customerId: filtered[i].id,
                                  ),
                                ),
                              ),
                              if (i != filtered.length - 1) const Divider(),
                            ],
                          ],
                        ),
                      ),
                  ],
                ),
              );
            },
          );
        },
        loading: () => const AppLoading(message: 'Loading customers…'),
        error: (error, stackTrace) => AppErrorState(
          message:
              "Couldn't load customers. Check your connection and try again.",
          onRetry: () => ref.invalidate(customersProvider),
        ),
      ),
    );
  }
}
