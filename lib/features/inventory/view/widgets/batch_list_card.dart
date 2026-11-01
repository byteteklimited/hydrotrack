import 'package:flutter/material.dart';

import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../data/models/stock_batch.dart';
import 'batch_tile.dart';

/// An item's batches, oldest (FIFO order) first — or the empty state
/// when every unit of it predates batch tracking, or none has arrived
/// yet.
class BatchListCard extends StatelessWidget {
  const BatchListCard({super.key, required this.batches, required this.unit});

  final List<StockBatch> batches;
  final String unit;

  @override
  Widget build(BuildContext context) {
    if (batches.isEmpty) {
      return const AppEmptyState(
        icon: Icons.inventory_2_outlined,
        title: 'No batches tracked',
        message:
            'Nothing recorded against this item has gone through batch '
            'tracking yet — stock added or produced from now on will show '
            'up here.',
      );
    }

    return AppCard(
      child: Column(
        children: [
          for (var i = 0; i < batches.length; i++) ...[
            BatchTile(batch: batches[i], unit: unit),
            if (i != batches.length - 1) const Divider(),
          ],
        ],
      ),
    );
  }
}
