import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

/// True when [error] means the server couldn't be reached at all (no
/// internet, DNS failure, timeout), as opposed to the server answering
/// with a refusal. Offline mode falls back to the device's own data only
/// for these.
bool isNetworkError(Object? error) {
  if (error is TimeoutException ||
      error is http.ClientException ||
      error is AuthRetryableFetchException) {
    return true;
  }
  final text = '$error';
  return text.contains('SocketException') ||
      text.contains('Failed host lookup') ||
      text.contains('XMLHttpRequest') ||
      text.contains('Failed to fetch') ||
      text.contains('Connection refused') ||
      text.contains('Connection reset') ||
      text.contains('Network is unreachable');
}

/// An action that only works online (staff, settings, voids, edits),
/// tried without internet or without an online sign-in.
class NeedsInternetException implements Exception {
  const NeedsInternetException([
    this.message =
        'This needs an internet connection. Connect and try again; '
        'everything else keeps working offline.',
  ]);

  final String message;

  @override
  String toString() => message;
}
