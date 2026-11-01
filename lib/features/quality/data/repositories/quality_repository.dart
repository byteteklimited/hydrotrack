import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/utils/query_range.dart';
import '../../../production/data/models/production_run.dart';
import '../models/batch_trace.dart';
import '../models/permit.dart';
import '../models/sanitation.dart';
import '../models/water_test.dart';

/// Quality and compliance records for the current organization: water
/// tests, the sanitation checklist, permits, and batch tracing.
abstract class QualityRepository {
  /// Tests on days from [from] up to (not including) [to], newest first.
  Future<List<WaterTest>> fetchWaterTests({DateTime? from, DateTime? to});
  Future<void> recordWaterTest({
    required DateTime date,
    required ProductionShift shift,
    required num ph,
    required num tds,
    required num chlorine,
    String? note,
  });

  /// Every item, stopped ones included, in checklist order.
  Future<List<SanitationItem>> fetchSanitationItems();
  Future<List<SanitationCheck>> fetchSanitationChecks({
    required DateTime from,
    required DateTime to,
  });
  Future<void> recordSanitationCheck(DateTime date, List<SanitationTick> ticks);
  Future<void> addSanitationItem(String name, int position);
  Future<void> updateSanitationItem(String id, {String? name, bool? isActive});

  /// Soonest to expire first.
  Future<List<Permit>> fetchPermits();

  /// Adds the permit, or updates it when [id] is given.
  Future<void> savePermit(Permit permit, {String? id});
  Future<void> deletePermit(String id);

  Future<BatchTrace> traceBatch(String batchNumber);
}

String _day(DateTime date) => date.toIso8601String().split('T').first;

class SupabaseQualityRepository implements QualityRepository {
  SupabaseQualityRepository(this._tenantId);

  final String _tenantId;

  SupabaseClient get _client => Supabase.instance.client;

  static const _waterTestColumns = '*, profiles!recorded_by(full_name)';
  static const _checkColumns = '*, profiles!checked_by(full_name)';

  /// What the server's `record_water_test` takes, without `p_`; also the
  /// offline record's payload.
  static Map<String, dynamic> waterTestPayload({
    required DateTime date,
    required ProductionShift shift,
    required num ph,
    required num tds,
    required num chlorine,
    String? note,
  }) => {
    'date': _day(date),
    'shift': shift.name,
    'ph': ph,
    'tds': tds,
    'chlorine': chlorine,
    'note': note,
  };

  static Map<String, dynamic> sanitationPayload(
    DateTime date,
    List<SanitationTick> ticks,
  ) => {
    'date': _day(date),
    'items': [for (final tick in ticks) tick.toJson()],
  };

  @override
  Future<List<WaterTest>> fetchWaterTests({
    DateTime? from,
    DateTime? to,
  }) async {
    final rows = await _client
        .from('water_tests')
        .select(_waterTestColumns)
        .eq('tenant_id', _tenantId)
        .inRange('date', from: from, to: to, dateOnly: true)
        .order('tested_at', ascending: false);
    return [
      for (final row in rows as List)
        WaterTest.fromJson(row as Map<String, dynamic>),
    ];
  }

  @override
  Future<void> recordWaterTest({
    required DateTime date,
    required ProductionShift shift,
    required num ph,
    required num tds,
    required num chlorine,
    String? note,
  }) {
    final payload = waterTestPayload(
      date: date,
      shift: shift,
      ph: ph,
      tds: tds,
      chlorine: chlorine,
      note: note,
    );
    return _client.rpc(
      'record_water_test',
      params: {
        'p_tenant_id': _tenantId,
        for (final entry in payload.entries) 'p_${entry.key}': entry.value,
      },
    );
  }

  @override
  Future<List<SanitationItem>> fetchSanitationItems() async {
    final rows = await _client
        .from('sanitation_items')
        .select()
        .eq('tenant_id', _tenantId)
        .order('position');
    return [
      for (final row in rows as List)
        SanitationItem.fromJson(row as Map<String, dynamic>),
    ];
  }

  @override
  Future<List<SanitationCheck>> fetchSanitationChecks({
    required DateTime from,
    required DateTime to,
  }) async {
    final rows = await _client
        .from('sanitation_checks')
        .select(_checkColumns)
        .eq('tenant_id', _tenantId)
        .inRange('date', from: from, to: to, dateOnly: true);
    return [
      for (final row in rows as List)
        SanitationCheck.fromJson(row as Map<String, dynamic>),
    ];
  }

  @override
  Future<void> recordSanitationCheck(
    DateTime date,
    List<SanitationTick> ticks,
  ) {
    final payload = sanitationPayload(date, ticks);
    return _client.rpc(
      'record_sanitation_check',
      params: {
        'p_tenant_id': _tenantId,
        'p_date': payload['date'],
        'p_items': payload['items'],
      },
    );
  }

  @override
  Future<void> addSanitationItem(String name, int position) {
    return _client.from('sanitation_items').insert({
      'tenant_id': _tenantId,
      'name': name,
      'position': position,
    });
  }

  @override
  Future<void> updateSanitationItem(String id, {String? name, bool? isActive}) {
    return _client
        .from('sanitation_items')
        .update({'name': ?name, 'is_active': ?isActive})
        .eq('tenant_id', _tenantId)
        .eq('id', id);
  }

  @override
  Future<List<Permit>> fetchPermits() async {
    final rows = await _client
        .from('permits')
        .select()
        .eq('tenant_id', _tenantId)
        .order('expires_on');
    return [
      for (final row in rows as List)
        Permit.fromJson(row as Map<String, dynamic>),
    ];
  }

  @override
  Future<void> savePermit(Permit permit, {String? id}) {
    final values = permit.toWriteJson();
    if (id == null) {
      return _client.from('permits').insert({
        'tenant_id': _tenantId,
        ...values,
      });
    }
    return _client
        .from('permits')
        .update(values)
        .eq('tenant_id', _tenantId)
        .eq('id', id);
  }

  @override
  Future<void> deletePermit(String id) {
    return _client
        .from('permits')
        .delete()
        .eq('tenant_id', _tenantId)
        .eq('id', id);
  }

  @override
  Future<BatchTrace> traceBatch(String batchNumber) async {
    final json = await _client.rpc(
      'trace_batch',
      params: {'p_tenant_id': _tenantId, 'p_batch_number': batchNumber},
    );
    return BatchTrace.fromJson(json as Map<String, dynamic>);
  }
}
