import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_card.dart';
import '../../data/models/driver.dart';
import '../../data/models/load_out.dart';
import '../../data/models/vehicle.dart';

/// One trip currently on the road: driver, vehicle, bags out, time out,
/// and the expected cash if everything sells.
class OnRoadLoadOutCard extends StatelessWidget {
  const OnRoadLoadOutCard({
    super.key,
    required this.loadOut,
    required this.driver,
    required this.vehicle,
    required this.onTap,
  });

  final LoadOut loadOut;
  final Driver driver;
  final Vehicle vehicle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final captionStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return AppCard(
      title: driver.name,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(vehicle.name, style: theme.textTheme.bodyMedium),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '${loadOut.bagsLoaded} bags out',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Out since ${DateFormat.jm().format(loadOut.dateTime)}',
            style: captionStyle,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '${formatNaira(loadOut.expectedCashFromLoad)} expected',
            style: captionStyle,
          ),
        ],
      ),
    );
  }
}
