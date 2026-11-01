import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_card.dart';
import '../../data/models/machine.dart';
import '../../data/providers/machines_providers.dart';

/// The last 30 days on one machine: breakdowns and diesel, newest first.
class MachineHistoryCard extends ConsumerWidget {
  const MachineHistoryCard({super.key, required this.machine});

  final Machine machine;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final breakdowns = [
      for (final b in ref.watch(breakdownsProvider).valueOrNull ?? const [])
        if (b.machineId == machine.id) b,
    ];
    final diesel = [
      for (final d in ref.watch(dieselLogsProvider).valueOrNull ?? const [])
        if (d.machineId == machine.id) d,
    ];
    final entries = <(DateTime, String, String)>[
      for (final b in breakdowns)
        (
          b.startedAt,
          'Stopped: ${b.cause}',
          b.isOpen
              ? 'Still stopped · ${formatPlain(b.downtimeHours(now))} hours'
              : '${formatPlain(b.downtimeHours(now))} hours down'
                    '${b.repairCost > 0 ? ' · repair ${formatNaira(b.repairCost)}' : ''}',
        ),
      for (final d in diesel)
        (
          d.date,
          'Diesel: ${formatPlain(d.litres)} litres',
          '${formatNaira(d.cost)} · ${d.recordedBy}'
              '${d.runHours == null ? '' : ' · ${formatPlain(d.runHours!)} hours run'}',
        ),
    ]..sort((a, b) => b.$1.compareTo(a.$1));

    return AppCard(
      title: 'Last 30 days',
      child: entries.isEmpty
          ? const Text('No breakdowns or diesel in the last 30 days.')
          : Column(
              children: [
                for (final (at, title, detail) in entries)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(title),
                    subtitle: Text(
                      '${DateFormat('d MMM').format(at)} · $detail',
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
              ],
            ),
    );
  }
}
