import 'package:flutter/material.dart';

import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_stat_strip.dart';
import '../../data/providers/sales_providers.dart';

/// The three numbers the owner checks first: cash today, transfer today,
/// and total bags sold today. Normal text color throughout — per the
/// brand guide, an amount isn't green just because it's cash; green is
/// reserved for an explicit in/out comparison, which this strip isn't.
class SalesTodayCard extends StatelessWidget {
  const SalesTodayCard({super.key, required this.totals});

  final SalesTotals totals;

  @override
  Widget build(BuildContext context) {
    return AppStatStrip(
      items: [
        AppStatStripItem(
          label: 'Cash today',
          value: formatNaira(totals.cashToday),
        ),
        AppStatStripItem(
          label: 'Transfer today',
          value: formatNaira(totals.transferToday),
        ),
        AppStatStripItem(
          label: 'Bags sold today',
          value: '${totals.bagsSoldToday}',
        ),
      ],
    );
  }
}
