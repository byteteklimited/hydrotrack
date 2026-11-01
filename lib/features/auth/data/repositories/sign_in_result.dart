/// Why a sign-in attempt failed. A typed reason, not an exception string,
/// so the UI decides what to say without parsing text.
enum SignInFailureReason {
  invalidCredentials,

  /// The server couldn't be reached (no internet).
  noConnection,
}

/// Outcome of an [AuthRepository.signIn] attempt. Signing in only proves
/// who someone is; which organization they work in is chosen afterwards.
sealed class SignInResult {
  const SignInResult();
}

final class SignInSuccess extends SignInResult {
  const SignInSuccess();
}

final class SignInFailure extends SignInResult {
  const SignInFailure(this.reason);
  final SignInFailureReason reason;
}

/// Outcome of creating an owner account with email + password.
enum SignUpOutcome {
  /// Signed in straight away (email confirmation is off).
  signedIn,

  /// Account created; the person must confirm their email, then sign in.
  confirmEmail,
}
