import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/plan.dart';

/// HydroTrack's plans — the same for every organization, so not
/// tenant-scoped. Anyone signed in can read them; only the admin console
/// changes them (AdminRepository.updatePlan).
abstract class PlanRepository {
  /// Cheapest first.
  Future<List<Plan>> fetchPlans();
}

class SupabasePlanRepository implements PlanRepository {
  SupabasePlanRepository();

  SupabaseClient get _client => Supabase.instance.client;

  @override
  Future<List<Plan>> fetchPlans() async {
    final rows = await _client
        .from('plans')
        .select(
          'key, name, description, monthly_price, max_staff, max_locations, '
          'is_popular',
        )
        .order('position');
    return [
      for (final row in rows as List)
        Plan.fromJson(row as Map<String, dynamic>),
    ];
  }
}
