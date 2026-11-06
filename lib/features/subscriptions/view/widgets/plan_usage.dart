import '../../data/models/subscription.dart';

/// One line of how much of the plan is in use; [over] when it's past the
/// limit (e.g. after moving to a smaller plan).
typedef PlanUsageLine = ({String text, bool over});

/// "Staff users: 2 of 3 (owners not counted)" and the same for locations.
List<PlanUsageLine> planUsageLines(Subscription subscription) {
  final plan = subscription.plan;
  if (plan == null) return const [];
  final staff = subscription.staffInUse;
  final locations = subscription.locationsInUse;
  final maxStaff = plan.maxStaff;
  final maxLocations = plan.maxLocations;
  return [
    (
      text: maxStaff == null
          ? 'Staff users: $staff (unlimited, owners not counted)'
          : 'Staff users: $staff of $maxStaff (owners not counted)'
                '${staff >= maxStaff ? ' · full' : ''}',
      over: maxStaff != null && staff > maxStaff,
    ),
    (
      text: maxLocations == null
          ? 'Factories and depots: $locations (no limit)'
          : 'Factories and depots: $locations of $maxLocations',
      over: maxLocations != null && locations > maxLocations,
    ),
  ];
}
