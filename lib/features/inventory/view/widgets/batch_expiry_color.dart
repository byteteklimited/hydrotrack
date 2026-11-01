import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/models/stock_batch.dart';

/// The one place a [BatchExpiryStatus] maps to a color — expired is red
/// (it must not be dispatched or sold), expiring soon is amber, anything
/// else stays neutral. Shared wherever a batch's expiry needs to read
/// the same way, same reasoning as [StockStatusColorX].
extension BatchExpiryStatusColorX on BatchExpiryStatus {
  Color? get color => switch (this) {
    BatchExpiryStatus.expired => AppColors.moneyOut,
    BatchExpiryStatus.expiringSoon => AppColors.lowStockWarning,
    BatchExpiryStatus.none => null,
  };
}
