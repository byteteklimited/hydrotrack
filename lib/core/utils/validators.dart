/// Form validators shared by the sign-in, account and invite screens.
/// Each returns the message to show under the field, or null when valid.
class Validators {
  Validators._();

  /// Local Nigerian mobile numbers, e.g. 08031234567.
  static const phoneLength = 11;

  /// Staff PINs are exactly this many digits (also the auth minimum
  /// password length configured on the Supabase project).
  static const pinLength = 6;

  /// Owner passwords: at least this many characters.
  static const passwordMinLength = 8;

  static final _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  static final _digits = RegExp(r'^\d+$');

  static String? required(String? value, String message) {
    return (value == null || value.trim().isEmpty) ? message : null;
  }

  static String? email(String? value) {
    return _email.hasMatch(value?.trim() ?? '')
        ? null
        : 'Enter a valid email address';
  }

  static String? phone(String? value) {
    final digits = value?.trim() ?? '';
    return digits.length == phoneLength && _digits.hasMatch(digits)
        ? null
        : 'Enter a valid $phoneLength-digit phone number';
  }

  /// Sign in accepts either a staff phone number or an owner's email.
  static String? phoneOrEmail(String? value) {
    final text = value?.trim() ?? '';
    if (text.contains('@')) return email(text);
    return phone(text) == null
        ? null
        : 'Enter your $phoneLength-digit phone number or your email';
  }

  static String? pin(String? value) {
    final text = value ?? '';
    return text.length == pinLength && _digits.hasMatch(text)
        ? null
        : 'PIN must be $pinLength digits';
  }

  static String? password(String? value) {
    return (value ?? '').length >= passwordMinLength
        ? null
        : 'Use at least $passwordMinLength characters';
  }
}
