import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../offline/data/services/offline_context.dart';
import '../models/owner_alert.dart';

/// Owner alerts. Needs internet (they're made on the server).
abstract class AlertsRepository {
  /// The last 30 days, newest first.
  Future<List<OwnerAlert>> fetchAlerts();
  Future<void> markAllRead();
}

class SupabaseAlertsRepository implements AlertsRepository {
  SupabaseAlertsRepository(this._tenantId);

  final String _tenantId;

  static const _keepDays = 30;

  SupabaseClient get _client => Supabase.instance.client;

  @override
  Future<List<OwnerAlert>> fetchAlerts() async {
    final since = DateTime.now().subtract(const Duration(days: _keepDays));
    final rows = await _client
        .from('alerts')
        .select('id, kind, title, body, created_at, read_at')
        .eq('tenant_id', _tenantId)
        .gte('created_at', since.toUtc().toIso8601String())
        .order('created_at', ascending: false);
    return [
      for (final row in rows as List)
        OwnerAlert.fromJson(row as Map<String, dynamic>),
    ];
  }

  @override
  Future<void> markAllRead() {
    return _client.rpc('mark_alerts_read', params: {'p_tenant_id': _tenantId});
  }
}

class OfflineAlertsRepository implements AlertsRepository {
  OfflineAlertsRepository(this._remote, this._offline);

  final AlertsRepository _remote;
  final OfflineContext _offline;

  @override
  Future<List<OwnerAlert>> fetchAlerts() =>
      _offline.online(_remote.fetchAlerts);

  @override
  Future<void> markAllRead() => _offline.online(_remote.markAllRead);
}
