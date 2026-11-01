import 'package:flutter/material.dart';

import '../../../../core/utils/date_utils.dart';
import '../../../../core/widgets/app_card.dart';
import '../../data/models/driver.dart';
import '../../data/models/load_out.dart';
import '../../data/models/vehicle.dart';
import 'settled_load_out_tile.dart';

/// One day's settled trips, grouped under a relative date header.
class SettledDaySection extends StatelessWidget {
  const SettledDaySection({
    super.key,
    required this.date,
    required this.loadOuts,
    required this.driversById,
    required this.vehiclesById,
  });

  final DateTime date;
  final List<LoadOut> loadOuts;
  final Map<String, Driver> driversById;
  final Map<String, Vehicle> vehiclesById;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      title: formatRelativeDay(date),
      child: Column(
        children: [
          for (var i = 0; i < loadOuts.length; i++) ...[
            SettledLoadOutTile(
              loadOut: loadOuts[i],
              driver: driversById[loadOuts[i].driverId]!,
              vehicle: vehiclesById[loadOuts[i].vehicleId]!,
            ),
            if (i != loadOuts.length - 1) const Divider(),
          ],
        ],
      ),
    );
  }
}
