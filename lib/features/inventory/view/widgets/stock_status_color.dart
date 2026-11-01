import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/models/stock_item.dart';

/// The one place a [StockStatus] maps to a color — out of stock is red
/// (it stops production), running low is amber, healthy stays neutral.
/// Shared by the item tile and the list screen's grouping so they can't
/// disagree about what each status means.
extension StockStatusColorX on StockStatus {
  Color? get color => switch (this) {
    StockStatus.outOfStock => AppColors.moneyOut,
    StockStatus.runningLow => AppColors.lowStockWarning,
    StockStatus.healthy => null,
  };
}
