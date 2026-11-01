import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/data/models/staff_user.dart';
import '../../../auth/data/providers/auth_providers.dart';
import '../widgets/permits_tab.dart';
import '../widgets/sanitation_tab.dart';
import '../widgets/water_tests_tab.dart';
import 'quality_settings_screen.dart';
import 'trace_batch_screen.dart';

/// Quality and NAFDAC compliance: water tests each shift, the daily
/// sanitation checklist, permits, and tracing a batch to customers.
class QualityScreen extends ConsumerWidget {
  const QualityScreen({super.key});

  void _push(BuildContext context, Widget screen) => Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => screen));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(authStateProvider)?.role;
    final canTrace = role?.canManage ?? false;
    final canConfigure = role?.isAdminLevel ?? false;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Quality'),
          actions: [
            if (canTrace)
              IconButton(
                icon: const Icon(Icons.manage_search),
                tooltip: 'Trace a batch',
                onPressed: () => _push(context, const TraceBatchScreen()),
              ),
            if (canConfigure)
              IconButton(
                icon: const Icon(Icons.tune),
                tooltip: 'Water limits and checklist',
                onPressed: () => _push(context, const QualitySettingsScreen()),
              ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Water tests'),
              Tab(text: 'Checklist'),
              Tab(text: 'Permits'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [WaterTestsTab(), SanitationTab(), PermitsTab()],
        ),
      ),
    );
  }
}
