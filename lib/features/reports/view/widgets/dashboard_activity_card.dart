import 'package:flutter/material.dart';

import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../data/models/dashboard_snapshot.dart';
import 'dashboard_activity_tile.dart';

/// Compact list of recent events — the visible face of the audit trail.
class DashboardActivityCard extends StatelessWidget {
  const DashboardActivityCard({super.key, required this.entries});

  final List<ActivityEntry> entries;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      title: "Today's activity",
      child: entries.isEmpty
          ? const AppEmptyState(
              compact: true,
              icon: Icons.history,
              title: 'Nothing yet today',
              message: 'Production, sales, and load-outs will show up here.',
            )
          : Column(
              children: [
                for (final entry in entries)
                  DashboardActivityTile(entry: entry),
              ],
            ),
    );
  }
}
