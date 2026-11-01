import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_status_tag.dart';
import '../../data/models/permit.dart';

/// One permit with how long it has left.
class PermitTile extends StatelessWidget {
  const PermitTile({super.key, required this.permit, this.onTap});

  final Permit permit;
  final VoidCallback? onTap;

  static (String, Color) tag(int daysLeft) {
    if (daysLeft < 0) return ('Expired', AppColors.dangerFg);
    if (daysLeft == 0) return ('Expires today', AppColors.dangerFg);
    final label = daysLeft == 1 ? '1 day left' : '$daysLeft days left';
    if (daysLeft <= Permit.dueSoonDays) return (label, AppColors.warningFg);
    return (label, AppColors.successFg);
  }

  @override
  Widget build(BuildContext context) {
    final daysLeft = permit.daysLeft(DateTime.now());
    final (label, color) = tag(daysLeft);
    final secondary = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppCard(
        onTap: onTap,
        title: permit.name,
        accentColor: daysLeft <= 0 ? AppColors.dangerFg : null,
        trailing: AppStatusTag(label: label, color: color),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Expires ${DateFormat('d MMM yyyy').format(permit.expiresOn)}',
            ),
            if (permit.number != null)
              Text('No. ${permit.number}', style: secondary),
            if (permit.note != null) Text(permit.note!, style: secondary),
          ],
        ),
      ),
    );
  }
}
