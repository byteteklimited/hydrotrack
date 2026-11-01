/// Spacing and radius constants on a 4px base scale.
///
/// Every gap, padding, and margin in the app should reference one of these —
/// no magic numbers in screens or widgets.
class AppSpacing {
  AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double lg2 = 20;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 40;
}

/// Standard border radius values, paired with [AppSpacing]. Dense and
/// restrained on purpose — this is a business tool, not a consumer app.
class AppRadius {
  AppRadius._();

  /// Text fields, dropdowns, chips, status badges, small icon badges.
  static const double input = 4;

  /// Buttons.
  static const double button = 6;

  /// Panels/cards.
  static const double panel = 8;

  /// Dialogs and the bottom-sheet modal every "record X"/detail screen
  /// opens in — a touch more than [panel] since a full sheet reads better
  /// with slightly softer corners, still capped well under anything
  /// decorative.
  static const double sheet = 10;
}

/// Standard animation durations, paired with [AppSpacing]/[AppRadius].
/// Used for hover/press/focus transitions — this app has no scattered
/// decorative animation, so these two cover everything it needs.
class AppDurations {
  AppDurations._();

  static const Duration fast = Duration(milliseconds: 120);
  static const Duration normal = Duration(milliseconds: 200);
}
