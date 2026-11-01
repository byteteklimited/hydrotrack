import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_routes.dart';
import '../../../../core/utils/action_controller.dart';
import '../../../auth/data/providers/auth_providers.dart';
import '../models/membership.dart';
import '../models/organization.dart';
import '../repositories/organization_repository.dart';

/// The active [OrganizationRepository] implementation.
final organizationRepositoryProvider = Provider<OrganizationRepository>(
  (ref) => SupabaseOrganizationRepository(),
);

/// The organization the app is currently working in, or null before one
/// is chosen (signed out, or on the organization picker).
final currentOrganizationProvider = StateProvider<Organization?>((ref) => null);

/// The current organization's id, for tenant-scoped repositories. Every
/// feature's repository provider watches this, so switching organization
/// rebuilds every repository — and with it every data provider — and no
/// screen can keep showing the previous organization's data.
///
/// Only read behind the organization picker, where one is always set;
/// reading it before then is a programming error, hence the throw.
final currentTenantIdProvider = Provider<String>((ref) {
  final organization = ref.watch(currentOrganizationProvider);
  if (organization == null) {
    throw StateError('No organization selected');
  }
  return organization.id;
});

/// Every organization the signed-in person belongs to.
final myMembershipsProvider = FutureProvider<List<Membership>>((ref) {
  return ref.watch(organizationRepositoryProvider).fetchMyMemberships();
});

/// Drives "Create organization", "Join with invite code" and
/// "Save name": loading while in flight, error with the server's reason
/// otherwise.
class OrganizationActionController extends ActionController {
  OrganizationActionController(this._ref);

  final Ref _ref;

  Future<Organization?> create(String name) {
    return guard(() async {
      final created = await _ref
          .read(organizationRepositoryProvider)
          .createOrganization(name);
      _ref.invalidate(myMembershipsProvider);
      return created;
    });
  }

  Future<String?> join(String code) {
    return guard(() async {
      final tenantId = await _ref
          .read(organizationRepositoryProvider)
          .joinWithCode(code);
      _ref.invalidate(myMembershipsProvider);
      return tenantId;
    });
  }

  Future<Organization?> rename({
    required String organizationId,
    required String name,
  }) {
    return guard(() async {
      final renamed = await _ref
          .read(organizationRepositoryProvider)
          .renameOrganization(organizationId: organizationId, name: name);
      _ref.read(currentOrganizationProvider.notifier).state = renamed;
      _ref.invalidate(myMembershipsProvider);
      return renamed;
    });
  }
}

/// Auto-disposed: each form opens with a clean state, never a previous
/// form's error.
final organizationActionControllerProvider =
    StateNotifierProvider.autoDispose<
      OrganizationActionController,
      AsyncValue<void>
    >((ref) => OrganizationActionController(ref));

/// Where to go once someone is signed in: straight into their last-used
/// organization (or their only one), otherwise the organization picker —
/// which also covers "not in any organization yet".
Future<void> enterApp(BuildContext context, WidgetRef ref) async {
  ref.invalidate(myMembershipsProvider);
  final memberships = await ref.read(myMembershipsProvider.future);
  if (!context.mounted) return;

  final active = memberships.where((m) => m.isActive).toList();
  final lastId = ref.read(organizationRepositoryProvider).lastOrganizationId();
  final preferred =
      active.where((m) => m.organization.id == lastId).firstOrNull ??
      (active.length == 1 ? active.first : null);

  if (preferred != null) {
    await openOrganization(context, ref, preferred);
    return;
  }
  Navigator.of(
    context,
  ).pushNamedAndRemoveUntil(AppRoutes.organizations, (route) => false);
}

/// Makes [membership]'s organization the current one and opens Home.
Future<void> openOrganization(
  BuildContext context,
  WidgetRef ref,
  Membership membership,
) async {
  ref.read(currentOrganizationProvider.notifier).state =
      membership.organization;
  ref.read(authStateProvider.notifier).state = membership.toStaffUser();
  Navigator.of(
    context,
  ).pushNamedAndRemoveUntil(AppRoutes.home, (route) => false);

  // A convenience for next time — never worth blocking or failing on.
  try {
    await ref
        .read(organizationRepositoryProvider)
        .rememberLastOrganization(membership.organization.id);
  } catch (_) {}
}

/// Leaves the current organization's screens for the picker, without
/// signing out.
void switchOrganization(BuildContext context, WidgetRef ref) {
  ref.invalidate(myMembershipsProvider);
  Navigator.of(
    context,
  ).pushNamedAndRemoveUntil(AppRoutes.organizations, (route) => false);
}
