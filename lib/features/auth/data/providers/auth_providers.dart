import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_routes.dart';
import '../../../../core/utils/action_controller.dart';
import '../../../admin/data/providers/admin_providers.dart';
import '../../../offline/data/providers/offline_providers.dart';
import '../../../offline/data/services/offline_controller.dart';
import '../../../organizations/data/models/organization.dart';
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

/// How someone got in.
enum SignInOutcome {
  /// With the server; pick the organization with [enterApp].
  online,

  /// Without internet, on a device set up for offline use; already in
  /// that device's organization.
  offline,
}

/// Drives the sign-in form: loading while in flight; on failure the error
/// is a [SignInFailureReason] or, offline, an [OfflineSignInFailure].
class SignInController extends StateNotifier<AsyncValue<void>> {
  SignInController(this._ref) : super(const AsyncValue.data(null));

  final Ref _ref;

  /// Null when refused.
  Future<SignInOutcome?> signIn({
    required String identifier,
    required String secret,
  }) async {
    state = const AsyncValue.loading();
    final result = await _ref
        .read(authRepositoryProvider)
        .signIn(identifier: identifier, secret: secret);
    switch (result) {
      case SignInSuccess():
        rememberForOfflineSignIn(_ref, secret);
        state = const AsyncValue.data(null);
        return SignInOutcome.online;
      case SignInFailure(reason: SignInFailureReason.noConnection):
        return _signInOffline(identifier: identifier, secret: secret);
      case SignInFailure(:final reason):
        state = AsyncValue.error(reason, StackTrace.current);
        return null;
    }
  }

  Future<SignInOutcome?> _signInOffline({
    required String identifier,
    required String secret,
  }) async {
    final offline = _ref.read(offlineControllerProvider.notifier);
    await offline.ready;
    final result = await offline.signIn(identifier: identifier, secret: secret);
    switch (result) {
      case OfflineSignInSuccess(:final member):
        _ref.read(currentOrganizationProvider.notifier).state =
            Organization.fromJson(offline.currentSnapshot!.organization);
        _ref.read(authStateProvider.notifier).state = member.toStaffUser();
        _ref.read(offlineSessionProvider.notifier).state = OfflineSession(
          identifier: identifier,
          secret: secret,
        );
        state = const AsyncValue.data(null);
        return SignInOutcome.offline;
      case OfflineSignInRefused(:final reason):
        state = AsyncValue.error(reason, StackTrace.current);
        return null;
    }
  }
}

/// After an online sign-in, saves a fresh offline sign-in check for this
/// person (in the background; never blocks or fails the sign-in).
void rememberForOfflineSignIn(Ref ref, String secret) {
  unawaited(
    ref
        .read(offlineControllerProvider.notifier)
        .saveCredential(secret)
        .catchError(
          (Object error) =>
              debugPrint('Saving offline sign-in check failed: $error'),
        ),
  );
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
      if (result is SignInSuccess) rememberForOfflineSignIn(_ref, pin);
      return result is SignInSuccess;
    });
    return joined ?? false;
  }

  /// Sets a new PIN with an admin's reset code, then signs straight in.
  Future<bool> resetPin({required String code, required String pin}) async {
    final done = await guard(() async {
      final repository = _ref.read(authRepositoryProvider);
      final phone = await repository.resetPinWithCode(code: code, pin: pin);
      final result = await repository.signIn(identifier: phone, secret: pin);
      if (result is SignInSuccess) rememberForOfflineSignIn(_ref, pin);
      return result is SignInSuccess;
    });
    return done ?? false;
  }

  Future<bool> sendPasswordReset(String email) async {
    final done = await guard(() async {
      await _ref.read(authRepositoryProvider).sendPasswordReset(email);
      return true;
    });
    return done ?? false;
  }

  Future<bool> setNewPassword(String password) async {
    final done = await guard(() async {
      await _ref.read(authRepositoryProvider).updatePassword(password);
      rememberForOfflineSignIn(_ref, password);
      return true;
    });
    return done ?? false;
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
  ref.read(offlineSessionProvider.notifier).state = null;
  ref.invalidate(myMembershipsProvider);
  ref.invalidate(isPlatformAdminProvider);
}
