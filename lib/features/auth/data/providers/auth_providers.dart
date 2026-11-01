import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_routes.dart';
import '../../../../core/utils/action_controller.dart';
import '../../../organizations/data/providers/organization_providers.dart';
import '../models/staff_user.dart';
import '../repositories/auth_repository.dart';
import '../repositories/sign_in_result.dart';

/// The active [AuthRepository] implementation.
final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => SupabaseAuthRepository(),
);

/// The signed-in person as a member of the current organization (their
/// role there), or null when signed out or before an organization is
/// chosen.
final authStateProvider = StateProvider<StaffUser?>((ref) => null);

/// Drives the sign-in form: loading while the request is in flight, error
/// when credentials are rejected.
class SignInController extends StateNotifier<AsyncValue<void>> {
  SignInController(this._ref) : super(const AsyncValue.data(null));

  final Ref _ref;

  /// True when signed in; where to go next is [enterApp]'s decision.
  Future<bool> signIn({
    required String identifier,
    required String secret,
  }) async {
    state = const AsyncValue.loading();
    final result = await _ref
        .read(authRepositoryProvider)
        .signIn(identifier: identifier, secret: secret);
    switch (result) {
      case SignInSuccess():
        state = const AsyncValue.data(null);
        return true;
      case SignInFailure(:final reason):
        state = AsyncValue.error(reason, StackTrace.current);
        return false;
    }
  }
}

final signInControllerProvider =
    StateNotifierProvider<SignInController, AsyncValue<void>>(
      (ref) => SignInController(ref),
    );

/// Drives "Create account" (owners) and "Join with invite code" (new
/// staff): loading while in flight, error with the server's reason.
class AccountSetupController extends ActionController {
  AccountSetupController(this._ref);

  final Ref _ref;

  Future<SignUpOutcome?> signUp({
    required String fullName,
    required String email,
    required String password,
  }) {
    return guard(
      () => _ref
          .read(authRepositoryProvider)
          .signUp(fullName: fullName, email: email, password: password),
    );
  }

  /// Creates the account from the invite, then signs straight in with it.
  Future<bool> joinWithInvite({
    required String code,
    required String pin,
  }) async {
    final joined = await guard(() async {
      final repository = _ref.read(authRepositoryProvider);
      final identifier = await repository.createAccountFromInvite(
        code: code,
        pin: pin,
      );
      final result = await repository.signIn(
        identifier: identifier,
        secret: pin,
      );
      return result is SignInSuccess;
    });
    return joined ?? false;
  }
}

/// Auto-disposed so an error from one screen (sign up / join) never shows
/// up on the other.
final accountSetupControllerProvider =
    StateNotifierProvider.autoDispose<AccountSetupController, AsyncValue<void>>(
      (ref) => AccountSetupController(ref),
    );

/// Signs out and returns to the login screen. Shared by every "Sign out"
/// control in the app (the sidebar footer, Home's account menu, the
/// organization picker) so they all call the exact same function.
Future<void> signOutAndReturnToLogin(
  BuildContext context,
  WidgetRef ref,
) async {
  await ref.read(authRepositoryProvider).signOut();
  if (context.mounted) {
    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(AppRoutes.login, (route) => false);
    // Clear the signed-in state only once the organization's screens are
    // gone; clearing it first makes them rebuild with no organization.
    await WidgetsBinding.instance.endOfFrame;
  }
  ref.read(authStateProvider.notifier).state = null;
  ref.read(currentOrganizationProvider.notifier).state = null;
  ref.invalidate(myMembershipsProvider);
}
