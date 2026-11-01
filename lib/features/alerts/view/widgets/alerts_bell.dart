import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/app_modal.dart';
import '../../data/providers/alerts_providers.dart';
import '../screens/alerts_screen.dart';

/// Home, for owners: alerts, with the number not yet read.
class AlertsBell extends ConsumerWidget {
  const AlertsBell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(unreadAlertCountProvider);
    return IconButton(
      tooltip: unread == 0 ? 'Alerts' : '$unread new alerts',
      icon: Badge(
        isLabelVisible: unread > 0,
        label: Text('$unread'),
        child: const Icon(Icons.notifications_outlined),
      ),
      onPressed: () =>
          showAppModal<void>(context, builder: (_) => const AlertsScreen()),
    );
  }
}
