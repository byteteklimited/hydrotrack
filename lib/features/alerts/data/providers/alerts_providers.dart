import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../offline/data/providers/offline_providers.dart';
import '../../../organizations/data/providers/organization_providers.dart';
import '../models/owner_alert.dart';
import '../repositories/alerts_repository.dart';

final alertsRepositoryProvider = Provider<AlertsRepository>((ref) {
  final remote = SupabaseAlertsRepository(ref.watch(currentTenantIdProvider));
  final offline = ref.watch(offlineContextProvider);
  return offline == null ? remote : OfflineAlertsRepository(remote, offline);
});

final alertsProvider = FutureProvider<List<OwnerAlert>>((ref) {
  return ref.watch(alertsRepositoryProvider).fetchAlerts();
});

/// For the bell: 0 when alerts can't be loaded (e.g. offline).
final unreadAlertCountProvider = Provider<int>((ref) {
  final alerts = ref.watch(alertsProvider).valueOrNull ?? const [];
  return alerts.where((alert) => !alert.isRead).length;
});
