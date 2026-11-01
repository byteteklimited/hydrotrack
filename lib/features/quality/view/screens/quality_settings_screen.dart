import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/responsive_center.dart';
import '../widgets/checklist_items_card.dart';
import '../widgets/water_limits_card.dart';

/// Owner/Admin: what a water test must read to pass, and what is on the
/// daily sanitation checklist.
class QualitySettingsScreen extends StatelessWidget {
  const QualitySettingsScreen({super.key});

  static const _maxContentWidth = 720.0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Water limits and checklist')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: const [
          ResponsiveCenter(
            maxWidth: _maxContentWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                WaterLimitsCard(),
                SizedBox(height: AppSpacing.lg),
                ChecklistItemsCard(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
