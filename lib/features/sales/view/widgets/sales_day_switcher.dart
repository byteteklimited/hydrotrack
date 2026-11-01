import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/app_day_switcher.dart';
import '../../data/providers/sales_providers.dart';

/// Moves the sales list between days.
class SalesDaySwitcher extends ConsumerWidget {
  const SalesDaySwitcher({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final day = ref.watch(selectedSalesDayProvider);
    return AppDaySwitcher(
      day: day,
      onChanged: (newDay) =>
          ref.read(selectedSalesDayProvider.notifier).state = newDay,
    );
  }
}
