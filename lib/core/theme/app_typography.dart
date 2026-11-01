import 'package:flutter/material.dart';

/// All text styling lives here. Screens and widgets must never call
/// [TextStyle] directly or reach for another font — everything routes
/// through [AppTypography].
///
/// Font: Helvetica, per the brand guide, with a fallback chain for
/// platforms/browsers that don't have it installed — no bundled font
/// files (licensing) and no `google_fonts`, so the fallback chain is what
/// actually renders on most web browsers and on Android; Helvetica itself
/// is only guaranteed present on iOS/macOS. Visually close enough
/// (Helvetica Neue/Arial are near-identical metrics) that this doesn't
/// need to be treated as a gap.
class AppTypography {
  AppTypography._();

  static const String _fontFamily = 'Helvetica';
  static const List<String> _fontFamilyFallback = [
    'Helvetica Neue',
    'Arial',
    'sans-serif',
  ];

  /// Complete Material 3 text theme, built on Helvetica. Sizes are the
  /// same scale the app already used; only the face and weights changed —
  /// page titles are Bold, section titles are Medium, body is Regular,
  /// per the brand guide.
  static TextTheme get textTheme => const TextTheme(
    displayLarge: TextStyle(fontSize: 57, fontWeight: FontWeight.w700),
    displayMedium: TextStyle(fontSize: 45, fontWeight: FontWeight.w700),
    displaySmall: TextStyle(fontSize: 36, fontWeight: FontWeight.w700),
    headlineLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.w700),
    headlineMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
    headlineSmall: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
    // Page title.
    titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
    // Section title.
    titleMedium: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
    titleSmall: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
    // Body.
    bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w400),
    bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w400),
    bodySmall: TextStyle(fontSize: 13, fontWeight: FontWeight.w400),
    // Labels/small captions — Medium, sentence case (never all-caps).
    labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
    labelMedium: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
    labelSmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
  ).apply(fontFamily: _fontFamily, fontFamilyFallback: _fontFamilyFallback);

  /// Metric value style for money amounts and headline stat figures.
  /// Tabular figures keep columns of numbers aligned; capped at 28, per
  /// the brand guide's "no 60px+ numbers" rule — this is a dense business
  /// tool, not a hero metric on a marketing page.
  static const TextStyle moneyLarge = TextStyle(
    fontFamily: _fontFamily,
    fontFamilyFallback: _fontFamilyFallback,
    fontSize: 28,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.3,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  /// Caption for stat labels ("Bags produced today"). Sentence case, a
  /// small amount of letter-spacing for legibility at this size — never
  /// the heavy all-caps tracking a generic template defaults to.
  static const TextStyle statLabel = TextStyle(
    fontFamily: _fontFamily,
    fontFamilyFallback: _fontFamilyFallback,
    fontSize: 13,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.1,
  );

  /// Compact tabular-figure style for numeric table columns — a running
  /// balance column, per-line amounts — where [moneyLarge] would be too
  /// big but figures still need to align.
  static const TextStyle tabularBody = TextStyle(
    fontFamily: _fontFamily,
    fontFamilyFallback: _fontFamilyFallback,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    fontFeatures: [FontFeature.tabularFigures()],
  );
}
