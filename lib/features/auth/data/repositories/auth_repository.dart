import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/utils/formatters.dart';
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

  bool get hasSession;

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
    } on AuthException catch (error) {
      // The UI only ever shows a generic "incorrect" message (never one
      // that hints which half was wrong) — the real reason still goes to
      // the console for debugging.
      debugPrint(
        'Sign-in failed: ${error.message} '
        '(status: ${error.statusCode}, code: ${error.code})',
      );
      return const SignInFailure(SignInFailureReason.invalidCredentials);
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
  bool get hasSession => _client.auth.currentSession != null;

  @override
  Future<void> signOut() => _client.auth.signOut();
}
