import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/app_day_switcher.dart';
import '../../data/providers/finance_providers.dart';

/// Moves the finance ledger between days.
class FinanceDaySwitcher extends ConsumerWidget {
  const FinanceDaySwitcher({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final day = ref.watch(selectedFinanceDayProvider);
    return AppDaySwitcher(
      day: day,
      onChanged: (newDay) =>
          ref.read(selectedFinanceDayProvider.notifier).state = newDay,
    );
  }
}
