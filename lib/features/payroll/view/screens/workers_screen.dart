import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/data/models/staff_user.dart';
import '../../../auth/data/providers/auth_providers.dart';
import '../widgets/attendance_tab.dart';
import '../widgets/bags_tab.dart';
import '../widgets/payroll_tab.dart';
import '../widgets/workers_tab.dart';

/// Workers & pay: daily attendance and bag counts (supervisors), the
/// worker list, and — for owners and admins only — rates, advances and
/// the monthly payroll.
class WorkersScreen extends ConsumerWidget {
  const WorkersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final seesPay = ref.watch(authStateProvider)?.role.isAdminLevel ?? false;
    final tabs = [
      ('Attendance', const AttendanceTab()),
      ('Bags', const BagsTab()),
      ('Workers', WorkersTab(seesPay: seesPay)),
      if (seesPay) ('Payroll', const PayrollTab()),
    ];

    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Workers & pay'),
          bottom: TabBar(
            isScrollable: true,
            tabs: [for (final (label, _) in tabs) Tab(text: label)],
          ),
        ),
        body: TabBarView(children: [for (final (_, tab) in tabs) tab]),
      ),
    );
  }
}
