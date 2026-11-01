import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../offline/data/services/offline_context.dart';
import '../models/organization_totals.dart';

/// All-time totals (organization_totals, migration 0019).
abstract class TotalsRepository {
  Future<OrganizationTotals> fetchTotals();
}

class SupabaseTotalsRepository implements TotalsRepository {
  SupabaseTotalsRepository(this._tenantId);

  final String _tenantId;

  @override
  Future<OrganizationTotals> fetchTotals() async {
    final row = await Supabase.instance.client.rpc(
      'organization_totals',
      params: {'p_tenant_id': _tenantId},
    );
    return OrganizationTotals.fromJson(row as Map<String, dynamic>);
  }
}

/// On a set-up device: the downloaded totals plus records made since.
class OfflineTotalsRepository implements TotalsRepository {
  OfflineTotalsRepository(this._remote, this._offline);

  final TotalsRepository _remote;
  final OfflineContext _offline;

  @override
  Future<OrganizationTotals> fetchTotals() {
    return _offline.read(
      remote: _remote.fetchTotals,
      local: (snapshot) => OrganizationTotals(
        totalBagsProduced: snapshot.totalBagsProduced,
        totalRevenue: snapshot.totalRevenue,
      ),
    );
  }
}
