import 'package:flutter/material.dart';

import '../../../../core/widgets/app_card.dart';
import '../../data/models/stock_item.dart';
import 'inventory_item_tile.dart';

/// A group of items inside the signature card — used both for the
/// "Running low" section and for the rest of a category's items.
class InventoryItemsCard extends StatelessWidget {
  const InventoryItemsCard({
    super.key,
    required this.items,
    required this.onItemTap,
    this.title,
    this.accentColor,
  });

  final List<StockItem> items;
  final ValueChanged<StockItem> onItemTap;
  final String? title;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      title: title,
      accentColor: accentColor,
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            InventoryItemTile(item: items[i], onTap: () => onItemTap(items[i])),
            if (i != items.length - 1) const Divider(),
          ],
        ],
      ),
    );
  }
}
