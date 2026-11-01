import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../offline/data/providers/offline_providers.dart';
import '../../../organizations/data/providers/organization_providers.dart';
import '../models/subscription.dart';
import '../models/subscription_event.dart';
import '../repositories/subscription_repository.dart';

final subscriptionRepositoryProvider = Provider<SubscriptionRepository>((ref) {
  final remote = SupabaseSubscriptionRepository(
    ref.watch(currentTenantIdProvider),
  );
  final offline = ref.watch(offlineContextProvider);
  return offline == null
      ? remote
      : OfflineSubscriptionRepository(remote, offline);
});

/// The current organization's subscription; null outside an organization
/// or when it can't be loaded (the banner then simply doesn't show).
final currentSubscriptionProvider = FutureProvider<Subscription?>((ref) async {
  if (ref.watch(currentOrganizationProvider) == null) return null;
  try {
    return await ref.watch(subscriptionRepositoryProvider).fetchSubscription();
  } catch (_) {
    return null;
  }
});

final subscriptionHistoryProvider =
    FutureProvider.autoDispose<List<SubscriptionEvent>>((ref) {
      return ref.watch(subscriptionRepositoryProvider).fetchHistory();
    });
