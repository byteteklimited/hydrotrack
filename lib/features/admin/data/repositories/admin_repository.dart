import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../subscriptions/data/models/subscription_event.dart';
import '../models/admin_organization.dart';
import '../models/platform_settings.dart';

/// The HydroTrack admin console: every organization and its subscription.
/// Not tenant-scoped — every call is checked on the server
/// (`require_platform_admin`), so this only works for platform admins.
abstract class AdminRepository {
  Future<bool> isPlatformAdmin();
  Future<List<AdminOrganization>> fetchOrganizations();
  Future<List<SubscriptionEvent>> fetchHistory(String organizationId);
  Future<void> recordPayment({
    required String organizationId,
    required num amount,
    required int months,
    String? note,
  });
  Future<void> addFreeDays({
    required String organizationId,
    required int days,
    String? note,
  });
  Future<void> setSuspended({
    required String organizationId,
    required bool suspended,
    String? reason,
  });
  Future<PlatformSettings> fetchSettings();
  Future<void> updateSettings(PlatformSettings settings);
}

class SupabaseAdminRepository implements AdminRepository {
  SupabaseClient get _client => Supabase.instance.client;

  @override
  Future<bool> isPlatformAdmin() async {
    if (_client.auth.currentUser == null) return false;
    return await _client.rpc('is_platform_admin') as bool;
  }

  @override
  Future<List<AdminOrganization>> fetchOrganizations() async {
    final rows = await _client.rpc('admin_organizations');
    return [
      for (final row in rows as List)
        AdminOrganization.fromJson(row as Map<String, dynamic>),
    ];
  }

  @override
  Future<List<SubscriptionEvent>> fetchHistory(String organizationId) async {
    final rows = await _client.rpc(
      'admin_subscription_events',
      params: {'p_tenant_id': organizationId},
    );
    return [
      for (final row in rows as List)
        SubscriptionEvent.fromJson(row as Map<String, dynamic>),
    ];
  }

  @override
  Future<void> recordPayment({
    required String organizationId,
    required num amount,
    required int months,
    String? note,
  }) {
    return _client.rpc(
      'admin_record_payment',
      params: {
        'p_tenant_id': organizationId,
        'p_amount': amount,
        'p_months': months,
        'p_note': note,
      },
    );
  }

  @override
  Future<void> addFreeDays({
    required String organizationId,
    required int days,
    String? note,
  }) {
    return _client.rpc(
      'admin_add_free_days',
      params: {'p_tenant_id': organizationId, 'p_days': days, 'p_note': note},
    );
  }

  @override
  Future<void> setSuspended({
    required String organizationId,
    required bool suspended,
    String? reason,
  }) {
    return _client.rpc(
      'admin_set_suspended',
      params: {
        'p_tenant_id': organizationId,
        'p_suspended': suspended,
        'p_reason': reason,
      },
    );
  }

  @override
  Future<PlatformSettings> fetchSettings() async {
    final row = await _client.rpc('admin_platform_settings');
    return PlatformSettings.fromJson(row as Map<String, dynamic>);
  }

  @override
  Future<void> updateSettings(PlatformSettings settings) {
    return _client.rpc(
      'admin_update_platform_settings',
      params: settings.toRpcParams(),
    );
  }
}
