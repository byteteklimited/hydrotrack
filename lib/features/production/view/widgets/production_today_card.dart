import 'package:flutter/material.dart';

import '../../../../core/constants/production_thresholds.dart';
import '../../../../core/widgets/app_stat_strip.dart';
import '../../data/providers/production_providers.dart';

/// Today's two production numbers, side by side: bags produced and
/// wastage — colored amber/red once it crosses the reorder-worthy
/// thresholds.
class ProductionTodayCard extends StatelessWidget {
  const ProductionTodayCard({super.key, required this.totals});

  final ProductionTotals totals;

  @override
  Widget build(BuildContext context) {
    return AppStatStrip(
      items: [
        AppStatStripItem(
          label: 'Bags produced today',
          value: '${totals.bagsProducedToday}',
        ),
        AppStatStripItem(
          label: 'Wastage today',
          value: '${totals.wastagePercentToday.toStringAsFixed(1)}%',
          valueColor: wastageColor(totals.wastagePercentToday),
          qualifier: '${totals.wastageToday} bags wasted',
        ),
      ],
    );
  }
}
