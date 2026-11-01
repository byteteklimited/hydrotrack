import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'network_error.dart';

/// Standard feedback for a failed write action (record sale, add stock,
/// record payment, ...) — almost always means no connection right now,
/// hence the default message. Pass [message] only when the failure is a
/// specific, actionable business rule the user needs to actually read
/// (e.g. "this item has history and can't be deleted") rather than a
/// generic connection problem.
void showActionErrorSnackBar(BuildContext context, {String? message}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        message ?? "Couldn't save — check your connection and try again.",
      ),
    ),
  );
}

/// Every Edge Function in this app (`accept-invite`)
/// reports its own rejection reason as `{"error": "..."}` in the HTTP
/// response body, which `functions.invoke` surfaces as a
/// [FunctionException]'s `details` — not a [PostgrestException], so the
/// usual `error.message` extraction used for RPC failures elsewhere in
/// this app doesn't apply here. Falls back to null (the generic
/// connection message) for anything else, including a
/// [FunctionsFetchException] (the request never reached the function at
/// all, e.g. a CORS or network failure) which has no such body to read.
String? edgeFunctionErrorMessage(Object? error) {
  if (error is! FunctionException) return null;
  final details = error.details;
  if (details is Map && details['error'] is String) {
    return details['error'] as String;
  }
  return error.reasonPhrase;
}

/// The specific, user-readable reason a write failed, when the backend
/// gave one: an RPC's own `raise exception` text (a [PostgrestException]),
/// an Edge Function's `{"error": "..."}` body, or an auth rejection.
/// Null for anything else (typically no connection), so callers fall back
/// to [showActionErrorSnackBar]'s generic message.
String? readableErrorMessage(Object? error) {
  return switch (error) {
    PostgrestException(:final message) => message,
    AuthException(:final message) => message,
    FunctionException() => edgeFunctionErrorMessage(error),
    NeedsInternetException(:final message) => message,
    StateError(:final message) => message,
    _ => null,
  };
}
