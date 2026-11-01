import 'package:flutter/material.dart';

import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../data/models/stock_movement.dart';
import 'stock_movement_tile.dart';

/// An item's movement ledger, newest first — or the empty state when
/// nothing has moved yet.
class MovementHistoryCard extends StatelessWidget {
  const MovementHistoryCard({
    super.key,
    required this.movements,
    required this.unit,
  });

  final List<StockMovement> movements;
  final String unit;

  @override
  Widget build(BuildContext context) {
    if (movements.isEmpty) {
      return const AppEmptyState(
        icon: Icons.receipt_long_outlined,
        title: 'No movements',
        message: 'No movements yet for this item.',
      );
    }

    return AppCard(
      child: Column(
        children: [
          for (var i = 0; i < movements.length; i++) ...[
            StockMovementTile(movement: movements[i], unit: unit),
            if (i != movements.length - 1) const Divider(),
          ],
        ],
      ),
    );
  }
}
