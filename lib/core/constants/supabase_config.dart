/// Supabase connection for the HydroTrack project (ref
/// `yvkwepipmpivybhhrhxr`). The defaults below let the app start however
/// it's launched (VS Code, Android Studio, plain `flutter run`). They are
/// safe to ship: a publishable key is public by design (it is inside every
/// web build) and row-level security is what protects the data.
///
/// To point a build at another hydrotrack environment, override both with
/// `--dart-define-from-file=.env.json` (see `.env.json.example`).
/// Only a publishable key ever belongs here; the service-role key stays
/// inside Edge Functions.
class SupabaseConfig {
  SupabaseConfig._();

  static const url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://yvkwepipmpivybhhrhxr.supabase.co',
  );
  static const publishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: 'sb_publishable_U3o0zaXUO8Q13ixHfEDDaA_zYm6vRxS',
  );

  /// Marker used by the placeholder values in `.env.json.example`, so an
  /// override copied without filling it in fails clearly at launch.
  static const _placeholderMarker = 'YOUR-';

  /// False when an override left either value empty or a placeholder.
  static bool get isConfigured =>
      url.isNotEmpty &&
      publishableKey.isNotEmpty &&
      !url.contains(_placeholderMarker) &&
      !publishableKey.contains(_placeholderMarker);
}
