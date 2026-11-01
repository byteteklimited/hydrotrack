import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/action_controller.dart';
import '../../../subscriptions/data/models/subscription_event.dart';
import '../../../subscriptions/data/providers/subscription_providers.dart';
import '../models/admin_organization.dart';
import '../models/platform_settings.dart';
import '../repositories/admin_repository.dart';

final adminRepositoryProvider = Provider<AdminRepository>(
  (ref) => SupabaseAdminRepository(),
);

/// Whether the signed-in account runs HydroTrack (shows the admin console
/// entry). False when it can't be checked, e.g. offline. Reset on sign-out.
final isPlatformAdminProvider = FutureProvider<bool>((ref) async {
  try {
    return await ref.watch(adminRepositoryProvider).isPlatformAdmin();
  } catch (_) {
    return false;
  }
});

final adminOrganizationsProvider =
    FutureProvider.autoDispose<List<AdminOrganization>>((ref) {
      return ref.watch(adminRepositoryProvider).fetchOrganizations();
    });

final adminHistoryProvider = FutureProvider.autoDispose
    .family<List<SubscriptionEvent>, String>((ref, organizationId) {
      return ref.watch(adminRepositoryProvider).fetchHistory(organizationId);
    });

final platformSettingsProvider = FutureProvider.autoDispose<PlatformSettings>((
  ref,
) {
  return ref.watch(adminRepositoryProvider).fetchSettings();
});

/// Record payment, free days, suspend/resume and plan settings.
class AdminActionController extends ActionController {
  AdminActionController(this._ref);

  final Ref _ref;

  AdminRepository get _repository => _ref.read(adminRepositoryProvider);

  Future<bool> recordPayment({
    required String organizationId,
    required num amount,
    required int months,
    String? note,
  }) => _changing(
    organizationId,
    () => _repository.recordPayment(
      organizationId: organizationId,
      amount: amount,
      months: months,
      note: note,
    ),
  );

  Future<bool> addFreeDays({
    required String organizationId,
    required int days,
    String? note,
  }) => _changing(
    organizationId,
    () => _repository.addFreeDays(
      organizationId: organizationId,
      days: days,
      note: note,
    ),
  );

  Future<bool> setSuspended({
    required String organizationId,
    required bool suspended,
    String? reason,
  }) => _changing(
    organizationId,
    () => _repository.setSuspended(
      organizationId: organizationId,
      suspended: suspended,
      reason: reason,
    ),
  );

  Future<bool> saveSettings(PlatformSettings settings) async {
    final saved = await guard(() async {
      await _repository.updateSettings(settings);
      _ref.invalidate(platformSettingsProvider);
      _ref.invalidate(adminOrganizationsProvider);
      return true;
    });
    return saved ?? false;
  }

  /// Runs a change to one organization, then refreshes what shows it —
  /// including the admin's own organization's banner, if it's that one.
  Future<bool> _changing(
    String organizationId,
    Future<void> Function() change,
  ) async {
    final done = await guard(() async {
      await change();
      _ref.invalidate(adminOrganizationsProvider);
      _ref.invalidate(adminHistoryProvider(organizationId));
      _ref.invalidate(currentSubscriptionProvider);
      return true;
    });
    return done ?? false;
  }
}

final adminActionControllerProvider =
    StateNotifierProvider.autoDispose<AdminActionController, AsyncValue<void>>(
      (ref) => AdminActionController(ref),
    );
