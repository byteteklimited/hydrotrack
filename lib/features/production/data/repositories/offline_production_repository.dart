import '../../../../core/utils/date_utils.dart';
import '../../../offline/data/models/outbox_operation.dart';
import '../../../offline/data/services/offline_context.dart';
import '../models/production_run.dart';
import 'production_repository.dart';

/// Production on a device set up for offline use: new runs are recorded
/// on the device first; editing or deleting a run needs internet.
class OfflineProductionRepository implements ProductionRepository {
  OfflineProductionRepository(this._remote, this._offline);

  final ProductionRepository _remote;
  final OfflineContext _offline;

  static const _notSynced =
      "This run hasn't reached the server yet. Try again once it has synced.";

  @override
  Future<List<ProductionRun>> fetchRuns({DateTime? from, DateTime? to}) {
    return _offline.read(
      remote: () => _remote.fetchRuns(from: from, to: to),
      local: (snapshot) =>
          snapshot
              .rows('production_runs')
              .map(ProductionRun.fromJson)
              .where((r) => isInRange(r.date, from: from, to: to))
              .toList()
            ..sort((a, b) => b.recordedAt.compareTo(a.recordedAt)),
    );
  }

  @override
  Future<ProductionRun> recordRun(
    ProductionRun run, {
    DateTime? expiryDate,
  }) async {
    final operation = await _offline.record(
      OperationType.productionRun,
      SupabaseProductionRepository.recordRunPayload(run, expiryDate),
    );
    return ProductionRun.fromJson(
      _offline.snapshot.row('production_runs', operation.opId)!,
    );
  }

  @override
  Future<ProductionRun> updateRun(ProductionRun run, {DateTime? expiryDate}) {
    return _offline.online(() {
      final serverId = _offline.serverIdOr(
        run.id,
        notSyncedMessage: _notSynced,
      );
      return _remote.updateRun(
        ProductionRun.fromJson({...run.toJson(), 'id': serverId}),
        expiryDate: expiryDate,
      );
    });
  }

  @override
  Future<void> deleteRun(String runId) {
    return _offline.online(
      () => _remote.deleteRun(
        _offline.serverIdOr(runId, notSyncedMessage: _notSynced),
      ),
    );
  }
}
