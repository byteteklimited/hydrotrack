import 'package:flutter/material.dart';

import '../../../../core/utils/date_utils.dart';
import '../../../../core/widgets/app_card.dart';
import '../../data/models/production_run.dart';
import 'production_run_tile.dart';

/// One day's group of runs inside the signature card, with a relative
/// date header ("Today", "Yesterday", or a short date).
class ProductionDaySection extends StatelessWidget {
  const ProductionDaySection({
    super.key,
    required this.date,
    required this.runs,
    required this.onRunTap,
  });

  final DateTime date;
  final List<ProductionRun> runs;
  final ValueChanged<ProductionRun> onRunTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      title: formatRelativeDay(date),
      child: Column(
        children: [
          for (var i = 0; i < runs.length; i++) ...[
            ProductionRunTile(run: runs[i], onTap: () => onRunTap(runs[i])),
            if (i != runs.length - 1) const Divider(),
          ],
        ],
      ),
    );
  }
}
