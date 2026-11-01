import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/utils/rpc_params.dart';
import '../models/production_run.dart';

/// Contract for reading, recording, and correcting production runs.
abstract class ProductionRepository {
  Future<List<ProductionRun>> fetchRuns();

  /// [expiryDate] is optional and only matters when [run.product] has a
  /// matching finished-goods catalog item — it becomes that output
  /// batch's expiry, not a column on `production_runs` itself.
  Future<ProductionRun> recordRun(ProductionRun run, {DateTime? expiryDate});

  /// Corrects an already-recorded run. Admin/Manager only (enforced by
  /// RLS) — `recordedBy`/`recordedAt` stay as the original author, this
  /// only changes the substantive fields.
  Future<ProductionRun> updateRun(ProductionRun run, {DateTime? expiryDate});

  /// Removes a mis-entered run entirely. Admin/Manager only (enforced by
  /// RLS). Irreversible — the caller is responsible for confirming first.
  Future<void> deleteRun(String runId);
}

/// Backed by the `production_runs` table, via RPCs rather than direct
/// writes — recording, editing, or deleting a run also keeps raw
/// material stock in sync with whatever recipe the product has defined
/// (supabase/migrations/0006_business_rpcs.sql), which a plain insert/update/delete can't express.
/// `recorded_by` is stored as the authenticated user's id; reads join
/// `profiles` to resolve it back to a display name.
class SupabaseProductionRepository implements ProductionRepository {
  SupabaseProductionRepository(this._tenantId);

  /// Every query and write is scoped to this organization.
  final String _tenantId;

  SupabaseClient get _client => Supabase.instance.client;

  static const _selectWithRecorder =
      '*, products(name, unit), profiles!recorded_by(full_name)';

  @override
  Future<List<ProductionRun>> fetchRuns() async {
    final rows = await _client
        .from('production_runs')
        .select(_selectWithRecorder)
        .eq('tenant_id', _tenantId)
        .order('recorded_at', ascending: false);
    return (rows as List)
        .map((row) => ProductionRun.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  /// record_production_run's values (without the `p_` prefix), shared
  /// with offline mode.
  static Map<String, dynamic> recordRunPayload(
    ProductionRun run,
    DateTime? expiryDate,
  ) => {
    'date': dateParam(run.date),
    'shift': run.shift.name,
    'machine': run.machine,
    'operator_name': run.operatorName,
    'product_id': run.product.id,
    'quantity_produced': run.quantityProduced,
    'wastage': run.wastage,
    'expiry_date': expiryDate == null ? null : dateParam(expiryDate),
  };

  @override
  Future<ProductionRun> recordRun(
    ProductionRun run, {
    DateTime? expiryDate,
  }) async {
    final runId = await _client.rpc(
      'record_production_run',
      params: rpcParams(_tenantId, recordRunPayload(run, expiryDate)),
    );

    final row = await _client
        .from('production_runs')
        .select(_selectWithRecorder)
        .eq('tenant_id', _tenantId)
        .eq('id', runId as String)
        .single();
    return ProductionRun.fromJson(row);
  }

  @override
  Future<ProductionRun> updateRun(
    ProductionRun run, {
    DateTime? expiryDate,
  }) async {
    await _client.rpc(
      'update_production_run',
      params: {
        'p_tenant_id': _tenantId,
        'p_run_id': run.id,
        'p_date': run.date.toIso8601String().split('T').first,
        'p_shift': run.shift.name,
        'p_machine': run.machine,
        'p_operator_name': run.operatorName,
        'p_product_id': run.product.id,
        'p_quantity_produced': run.quantityProduced,
        'p_wastage': run.wastage,
        'p_expiry_date': expiryDate?.toIso8601String().split('T').first,
      },
    );
    final row = await _client
        .from('production_runs')
        .select(_selectWithRecorder)
        .eq('tenant_id', _tenantId)
        .eq('id', run.id)
        .single();
    return ProductionRun.fromJson(row);
  }

  @override
  Future<void> deleteRun(String runId) {
    return _client.rpc(
      'delete_production_run',
      params: {'p_tenant_id': _tenantId, 'p_run_id': runId},
    );
  }
}
