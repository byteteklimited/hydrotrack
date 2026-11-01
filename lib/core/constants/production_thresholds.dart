import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Wastage-percentage cutoffs that drive color on the production screens.
class ProductionThresholds {
  ProductionThresholds._();

  static const double wastageAmberPercent = 1.5;
  static const double wastageRedPercent = 3.0;
}

/// The color a wastage *percentage* should show as — neutral below both
/// thresholds, amber past the first, red past the second. One shared rule
/// for every screen that shows wastage, so a run tile and the dashboard
/// card can never disagree about what counts as "bad". Never applied to a
/// bag/quantity count itself — only ever to a wastage figure.
Color? wastageColor(double wastagePercent) {
  if (wastagePercent > ProductionThresholds.wastageRedPercent) {
    return AppColors.moneyOut;
  }
  if (wastagePercent > ProductionThresholds.wastageAmberPercent) {
    return AppColors.lowStockWarning;
  }
  return null;
}
