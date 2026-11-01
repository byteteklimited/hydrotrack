/// Supabase project credentials for the HydroTrack project, injected at
/// build/run time via `--dart-define-from-file=.env.json` (see
/// `.env.json.example`). Never hardcode real values here — this file only
/// reads them. Only the publishable (anon) key ever belongs here; the
/// service-role key stays inside Edge Functions.
class SupabaseConfig {
  SupabaseConfig._();

  static const url = String.fromEnvironment('SUPABASE_URL');
  static const publishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
  );

  /// Marker used by the placeholder values in `.env.json.example` and the
  /// starter `.env.json`, so an unfilled config fails clearly at launch.
  static const _placeholderMarker = 'YOUR-';

  /// False when either value is missing or still a placeholder.
  static bool get isConfigured =>
      url.isNotEmpty &&
      publishableKey.isNotEmpty &&
      !url.contains(_placeholderMarker) &&
      !publishableKey.contains(_placeholderMarker);
}
