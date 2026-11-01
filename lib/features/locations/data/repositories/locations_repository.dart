import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/location.dart';

/// The organization's locations and who works where.
abstract class LocationsRepository {
  /// Every location, main first.
  Future<List<Location>> fetchLocations();

  /// Location ids the signed-in person is assigned to.
  Future<Set<String>> fetchMyLocationIds();

  /// Member id → location ids (owners and admins).
  Future<Map<String, Set<String>>> fetchAssignments();
  Future<void> saveLocation({
    required String name,
    required LocationKind kind,
    String? id,
    bool? isActive,
  });
  Future<void> setAssignments(String locationId, Set<String> memberIds);

  /// The location last worked in on this device, per organization.
  Future<String?> rememberedLocationId();
  Future<void> rememberLocation(String locationId);
}

class SupabaseLocationsRepository implements LocationsRepository {
  SupabaseLocationsRepository(this._tenantId);

  final String _tenantId;

  SupabaseClient get _client => Supabase.instance.client;

  String get _prefsKey => 'hydrotrack.location.$_tenantId';

  @override
  Future<List<Location>> fetchLocations() async {
    final rows = await _client
        .from('locations')
        .select()
        .eq('tenant_id', _tenantId)
        .order('is_main', ascending: false)
        .order('created_at');
    return [
      for (final row in rows as List)
        Location.fromJson(row as Map<String, dynamic>),
    ];
  }

  @override
  Future<Set<String>> fetchMyLocationIds() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return {};
    final rows = await _client
        .from('member_locations')
        .select('location_id')
        .eq('tenant_id', _tenantId)
        .eq('user_id', userId);
    return {
      for (final row in rows as List) (row as Map)['location_id'] as String,
    };
  }

  @override
  Future<Map<String, Set<String>>> fetchAssignments() async {
    final rows = await _client
        .from('member_locations')
        .select('user_id, location_id')
        .eq('tenant_id', _tenantId);
    final assignments = <String, Set<String>>{};
    for (final row in rows as List) {
      final map = row as Map;
      assignments
          .putIfAbsent(map['user_id'] as String, () => {})
          .add(map['location_id'] as String);
    }
    return assignments;
  }

  @override
  Future<void> saveLocation({
    required String name,
    required LocationKind kind,
    String? id,
    bool? isActive,
  }) {
    final values = {'name': name, 'kind': kind.name, 'is_active': ?isActive};
    if (id == null) {
      return _client.from('locations').insert({
        'tenant_id': _tenantId,
        ...values,
      });
    }
    return _client
        .from('locations')
        .update(values)
        .eq('tenant_id', _tenantId)
        .eq('id', id);
  }

  @override
  Future<void> setAssignments(String locationId, Set<String> memberIds) async {
    final current = await fetchAssignments();
    final had = {
      for (final entry in current.entries)
        if (entry.value.contains(locationId)) entry.key,
    };
    final add = memberIds.difference(had);
    final remove = had.difference(memberIds);
    if (add.isNotEmpty) {
      await _client.from('member_locations').insert([
        for (final userId in add)
          {
            'tenant_id': _tenantId,
            'user_id': userId,
            'location_id': locationId,
          },
      ]);
    }
    if (remove.isNotEmpty) {
      await _client
          .from('member_locations')
          .delete()
          .eq('tenant_id', _tenantId)
          .eq('location_id', locationId)
          .inFilter('user_id', remove.toList());
    }
  }

  @override
  Future<String?> rememberedLocationId() async =>
      (await SharedPreferences.getInstance()).getString(_prefsKey);

  @override
  Future<void> rememberLocation(String locationId) async =>
      (await SharedPreferences.getInstance()).setString(_prefsKey, locationId);
}
