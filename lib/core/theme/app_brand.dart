/// HydroTrack's own logo, shown before an organization is open (splash,
/// sign-in); inside one, the organization's own logo is used instead
/// (OrganizationLogo). Registered via `assets/brand/` in `pubspec.yaml`,
/// with sharper 2.0x/3.0x versions picked automatically. The source
/// artwork (SVG, app icons) lives in `design/brand/`.
class AppBrand {
  AppBrand._();

  static const String logo = 'assets/brand/hydrotrack_logo.png';

  /// The logo is wide (about 5:1): sized so it fits a phone screen.
  static const double splashWidth = 260;
  static const double signInHeight = 44;
}
