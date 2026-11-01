import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/utils/rpc_params.dart';
import '../models/sync_flag.dart';
import '../services/offline_context.dart';

/// Records made offline that a manager should check.
abstract class SyncFlagsRepository {
  /// Not yet checked, newest first.
  Future<List<SyncFlag>> fetchOpenFlags();

  /// Owner/Admin/Manager.
  Future<void> markChecked(String flagId);
}

class SupabaseSyncFlagsRepository implements SyncFlagsRepository {
  SupabaseSyncFlagsRepository(this._tenantId);

  final String _tenantId;

  SupabaseClient get _client => Supabase.instance.client;

  @override
  Future<List<SyncFlag>> fetchOpenFlags() async {
    final rows = await _client
        .from('sync_flags')
        .select()
        .eq('tenant_id', _tenantId)
        .isFilter('checked_at', null)
        .order('created_at', ascending: false);
    return [
      for (final row in rows as List)
        SyncFlag.fromJson(row as Map<String, dynamic>),
    ];
  }

  @override
  Future<void> markChecked(String flagId) {
    return _client.rpc(
      'mark_sync_flag_checked',
      params: rpcParams(_tenantId, {'flag_id': flagId}),
    );
  }
}

class OfflineSyncFlagsRepository implements SyncFlagsRepository {
  OfflineSyncFlagsRepository(this._remote, this._offline);

  final SyncFlagsRepository _remote;
  final OfflineContext _offline;

  @override
  Future<List<SyncFlag>> fetchOpenFlags() {
    return _offline.read(
      remote: _remote.fetchOpenFlags,
      local: (snapshot) =>
          snapshot.rows('sync_flags').map(SyncFlag.fromJson).toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
    );
  }

  @override
  Future<void> markChecked(String flagId) {
    return _offline.online(() => _remote.markChecked(flagId));
  }
}
