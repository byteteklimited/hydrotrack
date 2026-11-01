import '../../../../core/utils/date_utils.dart';
import '../../../offline/data/models/outbox_operation.dart';
import '../../../offline/data/services/offline_context.dart';
import '../../../production/data/models/production_run.dart';
import '../models/batch_trace.dart';
import '../models/permit.dart';
import '../models/sanitation.dart';
import '../models/water_test.dart';
import 'quality_repository.dart';

/// On a device set up for offline use: water tests and the checklist are
/// saved on the device first, then sent; settings, permits and tracing
/// need internet.
class OfflineQualityRepository implements QualityRepository {
  OfflineQualityRepository(this._remote, this._offline);

  final QualityRepository _remote;
  final OfflineContext _offline;

  @override
  Future<List<WaterTest>> fetchWaterTests({DateTime? from, DateTime? to}) {
    return _offline.read(
      remote: () => _remote.fetchWaterTests(from: from, to: to),
      local: (snapshot) =>
          snapshot
              .rows('water_tests')
              .map(WaterTest.fromJson)
              .where((test) => isInRange(test.date, from: from, to: to))
              .toList()
            ..sort((a, b) => b.testedAt.compareTo(a.testedAt)),
    );
  }

  @override
  Future<void> recordWaterTest({
    required DateTime date,
    required ProductionShift shift,
    required num ph,
    required num tds,
    required num chlorine,
    String? note,
  }) async {
    await _offline.record(
      OperationType.waterTest,
      SupabaseQualityRepository.waterTestPayload(
        date: date,
        shift: shift,
        ph: ph,
        tds: tds,
        chlorine: chlorine,
        note: note,
      ),
    );
  }

  @override
  Future<List<SanitationItem>> fetchSanitationItems() {
    return _offline.read(
      remote: _remote.fetchSanitationItems,
      local: (snapshot) =>
          snapshot
              .rows('sanitation_items')
              .map(SanitationItem.fromJson)
              .toList()
            ..sort((a, b) => a.position.compareTo(b.position)),
    );
  }

  @override
  Future<List<SanitationCheck>> fetchSanitationChecks({
    required DateTime from,
    required DateTime to,
  }) {
    return _offline.read(
      remote: () => _remote.fetchSanitationChecks(from: from, to: to),
      local: (snapshot) => snapshot
          .rows('sanitation_checks')
          .map(SanitationCheck.fromJson)
          .where((check) => isInRange(check.date, from: from, to: to))
          .toList(),
    );
  }

  @override
  Future<void> recordSanitationCheck(
    DateTime date,
    List<SanitationTick> ticks,
  ) async {
    await _offline.record(
      OperationType.sanitationCheck,
      SupabaseQualityRepository.sanitationPayload(date, ticks),
    );
  }

  @override
  Future<void> addSanitationItem(String name, int position) =>
      _offline.online(() => _remote.addSanitationItem(name, position));

  @override
  Future<void> updateSanitationItem(
    String id, {
    String? name,
    bool? isActive,
  }) => _offline.online(
    () => _remote.updateSanitationItem(id, name: name, isActive: isActive),
  );

  @override
  Future<List<Permit>> fetchPermits() {
    return _offline.read(
      remote: _remote.fetchPermits,
      local: (snapshot) =>
          snapshot.rows('permits').map(Permit.fromJson).toList()
            ..sort((a, b) => a.expiresOn.compareTo(b.expiresOn)),
    );
  }

  @override
  Future<void> savePermit(Permit permit, {String? id}) =>
      _offline.online(() => _remote.savePermit(permit, id: id));

  @override
  Future<void> deletePermit(String id) =>
      _offline.online(() => _remote.deletePermit(id));

  @override
  Future<BatchTrace> traceBatch(String batchNumber) =>
      _offline.online(() => _remote.traceBatch(batchNumber));
}
