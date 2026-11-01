import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/models/sale.dart';

/// The one place a [SalePaymentStatus] maps to a color — paid is green
/// (confirmed positive outcome), part-paid is amber (still owed, but
/// progress made), on credit is red (nothing paid). Shared by the status
/// badge and the receipt's balance row so they can't disagree about what
/// each status means.
extension SalePaymentStatusColorX on SalePaymentStatus {
  Color? get color => switch (this) {
    SalePaymentStatus.paid => AppColors.moneyIn,
    SalePaymentStatus.partPaid => AppColors.lowStockWarning,
    SalePaymentStatus.onCredit => AppColors.moneyOut,
  };
}
