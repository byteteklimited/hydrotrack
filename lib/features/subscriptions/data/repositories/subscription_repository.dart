import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../offline/data/services/offline_context.dart';
import '../models/subscription.dart';
import '../models/subscription_event.dart';

/// The current organization's subscription.
abstract class SubscriptionRepository {
  /// Null when the server has no subscription for it (never in practice).
  Future<Subscription?> fetchSubscription();

  /// Payments and free days, newest first (owners only; others get none).
  Future<List<SubscriptionEvent>> fetchHistory();
}

class SupabaseSubscriptionRepository implements SubscriptionRepository {
  SupabaseSubscriptionRepository(this._tenantId);

  final String _tenantId;

  SupabaseClient get _client => Supabase.instance.client;

  @override
  Future<Subscription?> fetchSubscription() async {
    final json = await _client.rpc(
      'my_subscription',
      params: {'p_tenant_id': _tenantId},
    );
    return json == null
        ? null
        : Subscription.fromJson(json as Map<String, dynamic>);
  }

  @override
  Future<List<SubscriptionEvent>> fetchHistory() async {
    final rows = await _client
        .from('subscription_events')
        .select('id, kind, amount, months, days, note, ends_at, created_at')
        .eq('tenant_id', _tenantId)
        .order('created_at', ascending: false);
    return [
      for (final row in rows as List)
        SubscriptionEvent.fromJson(row as Map<String, dynamic>),
    ];
  }
}

/// On a set-up device: the status from the last download when offline.
class OfflineSubscriptionRepository implements SubscriptionRepository {
  OfflineSubscriptionRepository(this._remote, this._offline);

  final SubscriptionRepository _remote;
  final OfflineContext _offline;

  @override
  Future<Subscription?> fetchSubscription() => _offline.read(
    remote: _remote.fetchSubscription,
    local: (snapshot) => snapshot.subscription == null
        ? null
        : Subscription.fromJson(snapshot.subscription!),
  );

  @override
  Future<List<SubscriptionEvent>> fetchHistory() =>
      _offline.online(_remote.fetchHistory);
}
