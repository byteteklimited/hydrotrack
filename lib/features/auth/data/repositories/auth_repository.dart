import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/network_error.dart';
import 'sign_in_result.dart';

/// Contract for authentication. Proves who someone is; which organization
/// they work in (and their role there) is handled by the organizations
/// feature afterwards.
abstract class AuthRepository {
  /// [identifier] is a phone number (staff, with a 6-digit PIN) or an
  /// email address (owners, with a password).
  Future<SignInResult> signIn({
    required String identifier,
    required String secret,
  });

  /// Creates an owner account with email + password.
  Future<SignUpOutcome> signUp({
    required String fullName,
    required String email,
    required String password,
  });

  /// Creates a phone + PIN account from an invite code (via the
  /// `accept-invite` Edge Function) and joins its organization. Returns
  /// the identifier to sign in with.
  Future<String> createAccountFromInvite({
    required String code,
    required String pin,
  });

  /// Sets a new PIN with a reset code from an admin (`reset-pin` Edge
  /// Function). Returns the phone number to sign in with.
  Future<String> resetPinWithCode({required String code, required String pin});

  /// Emails an owner a link to set a new password.
  Future<void> sendPasswordReset(String email);

  /// Sets a new password for the signed-in account (after opening the
  /// reset link).
  Future<void> updatePassword(String password);

  /// The email the signed-in account signs in with; null for accounts
  /// that sign in with a phone number (and a PIN).
  String? get signInEmail;

  /// Renames the signed-in person everywhere their name shows.
  Future<void> updateFullName(String fullName);

  /// Checks [current] by signing in again with [identifier], then sets
  /// [next] as the new PIN or password. Throws [StateError] with a
  /// readable message when [current] is wrong.
  Future<void> changeSecret({
    required String identifier,
    required String current,
    required String next,
  });

  /// Fires when someone opens a password reset link.
  Stream<void> get passwordRecoveries;

  bool get hasSession;

  /// The account with an online session on this device, if any.
  String? get signedInUserId;

  Future<void> signOut();
}

/// Supabase Auth. Phone numbers are typed and shown in local format and
/// only converted to E.164 for auth calls.
class SupabaseAuthRepository implements AuthRepository {
  SupabaseClient get _client => Supabase.instance.client;

  static bool _isEmail(String identifier) => identifier.contains('@');

  @override
  Future<SignInResult> signIn({
    required String identifier,
    required String secret,
  }) async {
    try {
      final response = _isEmail(identifier)
          ? await _client.auth.signInWithPassword(
              email: identifier.toLowerCase(),
              password: secret,
            )
          : await _client.auth.signInWithPassword(
              phone: toE164Nigeria(identifier),
              password: secret,
            );
      return response.user == null
          ? const SignInFailure(SignInFailureReason.invalidCredentials)
          : const SignInSuccess();
    } on AuthRetryableFetchException {
      return const SignInFailure(SignInFailureReason.noConnection);
    } on AuthException catch (error) {
      // The UI only ever shows a generic "incorrect" message (never one
      // that hints which half was wrong) — the real reason still goes to
      // the console for debugging.
      debugPrint(
        'Sign-in failed: ${error.message} '
        '(status: ${error.statusCode}, code: ${error.code})',
      );
      return const SignInFailure(SignInFailureReason.invalidCredentials);
    } catch (error) {
      if (isNetworkError(error)) {
        return const SignInFailure(SignInFailureReason.noConnection);
      }
      rethrow;
    }
  }

  @override
  Future<SignUpOutcome> signUp({
    required String fullName,
    required String email,
    required String password,
  }) async {
    final response = await _client.auth.signUp(
      email: email.toLowerCase(),
      password: password,
      data: {'full_name': fullName},
      // On the web, the confirmation link comes back to the address the
      // owner signed up on (it must be in Supabase's Redirect URLs).
      emailRedirectTo: kIsWeb ? '${Uri.base.origin}/' : null,
    );
    return response.session == null
        ? SignUpOutcome.confirmEmail
        : SignUpOutcome.signedIn;
  }

  @override
  Future<String> createAccountFromInvite({
    required String code,
    required String pin,
  }) async {
    final response = await _client.functions.invoke(
      'accept-invite',
      body: {'code': code, 'pin': pin},
    );
    final data = response.data as Map<String, dynamic>;
    return (data['phone'] ?? data['email']) as String;
  }

  @override
  Future<String> resetPinWithCode({
    required String code,
    required String pin,
  }) async {
    final response = await _client.functions.invoke(
      'reset-pin',
      body: {'code': code, 'pin': pin},
    );
    return (response.data as Map<String, dynamic>)['phone'] as String;
  }

  @override
  Future<void> sendPasswordReset(String email) {
    return _client.auth.resetPasswordForEmail(
      email.trim().toLowerCase(),
      // Web: come back to this same app. Elsewhere: the project's Site URL.
      redirectTo: kIsWeb ? '${Uri.base.origin}/' : null,
    );
  }

  @override
  Future<void> updatePassword(String password) {
    return _client.auth.updateUser(UserAttributes(password: password));
  }

  @override
  String? get signInEmail {
    final email = _client.auth.currentUser?.email;
    return email == null || email.isEmpty ? null : email;
  }

  @override
  Future<void> updateFullName(String fullName) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw StateError('Sign in again, then try again.');
    await _client
        .from('profiles')
        .update({'full_name': fullName})
        .eq('id', userId);
    await _client.auth.updateUser(
      UserAttributes(data: {'full_name': fullName}),
    );
  }

  @override
  Future<void> changeSecret({
    required String identifier,
    required String current,
    required String next,
  }) async {
    final check = await signIn(identifier: identifier, secret: current);
    switch (check) {
      case SignInSuccess():
        await updatePassword(next);
      case SignInFailure(reason: SignInFailureReason.noConnection):
        throw const NeedsInternetException();
      case SignInFailure():
        throw StateError(
          _isEmail(identifier)
              ? 'Your current password is not right.'
              : 'Your current PIN is not right.',
        );
    }
  }

  @override
  Stream<void> get passwordRecoveries => _client.auth.onAuthStateChange
      .where((state) => state.event == AuthChangeEvent.passwordRecovery)
      .map((_) {});

  @override
  bool get hasSession => _client.auth.currentSession != null;

  @override
  String? get signedInUserId => _client.auth.currentUser?.id;

  @override
  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } catch (error) {
      // Offline: the server can't be told, but the session on this device
      // is still cleared by the client.
      if (!isNetworkError(error)) rethrow;
    }
  }
}
