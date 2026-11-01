import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_stat_strip.dart';
import '../../data/providers/machines_providers.dart';

/// This month: bags made, diesel used and per bag, and downtime.
class MachineMonthCard extends ConsumerWidget {
  const MachineMonthCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportAsync = ref.watch(machineReportProvider);
    final report = reportAsync.valueOrNull;
    return AppCard(
      title: 'This month',
      child: report == null
          ? Text(
              reportAsync.isLoading
                  ? 'Loading…'
                  : "This month's figures need internet.",
              style: const TextStyle(color: AppColors.textSecondary),
            )
          : AppStatStrip(
              items: [
                AppStatStripItem(
                  label: 'Bags made',
                  value: formatQuantity(report.bags, 'bags'),
                ),
                AppStatStripItem(
                  label: 'Diesel used',
                  value: '${formatPlain(report.litres)} litres',
                ),
                AppStatStripItem(
                  label: 'Diesel per 100 bags',
                  value: report.litresPer100Bags == null
                      ? '—'
                      : '${formatPlain(report.litresPer100Bags!)} litres',
                ),
                AppStatStripItem(
                  label: 'Diesel cost per bag',
                  value: report.dieselCostPerBag == null
                      ? '—'
                      : formatNairaWithKobo(report.dieselCostPerBag!),
                ),
                AppStatStripItem(
                  label: 'Downtime',
                  value: '${formatPlain(report.downtimeHours)} hours',
                ),
              ],
            ),
    );
  }
}
