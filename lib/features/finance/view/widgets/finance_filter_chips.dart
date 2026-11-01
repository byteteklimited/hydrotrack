import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../data/providers/finance_providers.dart';

extension on FinanceFilter {
  String get label => switch (this) {
    FinanceFilter.all => 'All',
    FinanceFilter.moneyIn => 'Money in',
    FinanceFilter.moneyOut => 'Money out',
  };
}

/// All / Money in / Money out — filters the ledger below.
class FinanceFilterChips extends ConsumerWidget {
  const FinanceFilterChips({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(financeFilterProvider);

    return Wrap(
      spacing: AppSpacing.sm,
      children: [
        for (final filter in FinanceFilter.values)
          ChoiceChip(
            label: Text(filter.label),
            selected: selected == filter,
            onSelected: (_) =>
                ref.read(financeFilterProvider.notifier).state = filter,
          ),
      ],
    );
  }
}
