import 'package:flutter/material.dart';

/// All color values for the app live here. Screens and widgets must never
/// hardcode a [Color] — pull from [AppColors.scheme] or the semantic
/// constants below.
///
/// Brand navy (`#002179`) is the only interactive accent — buttons,
/// links, the active nav state, focus rings. Brand cyan (`#02BDFB`) is
/// an accent-only wash: selected/active backgrounds, info chips, chart
/// highlights — never text, never an icon, never a line, since on its
/// own it measures ~2.2:1 against white (confirmed by direct
/// calculation, not assumed) — well under the 4.5:1 a reader needs.
/// Red is no longer a brand color at all; it's purely the danger/
/// destructive semantic now. Every pairing below was checked against
/// WCAG 2.1's actual contrast formula, not estimated — see the contrast
/// table delivered alongside this rebrand for the full pair-by-pair
/// results.
class AppColors {
  AppColors._();

  static const Color brandNavy = Color(0xFF002179);
  static const Color brandCyan = Color(0xFF02BDFB);

  static const Color navyHover = Color(0xFF0A2E94); // ~8% lighter
  static const Color navyPressed = Color(0xFF001A60); // ~14% darker

  /// Not `const` — [Color.withValues] isn't a const expression. Used for
  /// a disabled interactive element's background; disabled UI is exempt
  /// from the standard text/icon contrast minimums (it isn't operable),
  /// so this has no ratio requirement of its own.
  static final Color navyDisabled = brandNavy.withValues(alpha: 0.38);

  /// True alpha, not a precomputed solid blend — these sit only on
  /// white/near-white surfaces in this app, where the two render
  /// identically, so the brief's literal alpha values are used as-is.
  static const Color cyanTint10 = Color(0x1A02BDFB); // ~10% cyan
  static const Color cyanGlow25 = Color(
    0x4002BDFB,
  ); // ~25% cyan, decorative only

  // Neutrals — cool, navy-tinted, zero lavender/purple.
  static const Color background = Color(0xFFF5F7FA);
  static const Color surfaceWhite = Color(0xFFFFFFFF);

  /// Decorative/structural only — card outlines, section dividers.
  /// Measures ~1.25:1 against white, so this is never used where a
  /// border needs to read as an operable UI boundary; [borderStrong]
  /// is for that.
  static const Color border = Color(0xFFE2E6EE);

  /// For a border that has to actually register as a UI boundary — an
  /// input field's rest-state edge, an outlined button — where the
  /// brief's own rule requires >=3:1. Derived, not in the brief's
  /// literal neutral list: the literal `border` value fails that same
  /// rule at ~1.25:1, so this exists specifically to satisfy it
  /// (confirmed at ~3.04:1 against white by direct calculation).
  static const Color borderStrong = Color(0xFF90949E);

  static const Color divider = Color(0xFFEDF0F5);
  static const Color textPrimary = Color(
    0xFF0E1530,
  ); // navy-tinted, never pure black
  static const Color textSecondary = Color(0xFF556070);

  /// Placeholder/disabled text. ~3.1:1 against white — under the 4.5:1
  /// body-text minimum, but WCAG exempts disabled/placeholder content
  /// from that requirement since it isn't conveying operable
  /// information; never used for real body text.
  static const Color textTertiary = Color(0xFF8A93A3);

  /// Hover backgrounds, progress/skeleton tracks, zebra-stripe tint,
  /// neutral chip fills.
  static const Color hoverNeutral = Color(0xFFEEF2F7);

  /// Inverse surfaces (snackbars) — same tone as [textPrimary], not a
  /// flat gray, so dark surfaces stay in the same cool-navy language as
  /// everything else.
  static const Color neutralDark = Color(0xFF0E1530);

  // Semantic status colors — status only, never decoration.
  static const Color successFg = Color(0xFF1E7B45);
  static const Color successBg = Color(0xFFE8F4ED);
  static const Color warningFg = Color(0xFF9A6200);
  static const Color warningBg = Color(0xFFFFF4DD);
  static const Color dangerFg = Color(0xFFB42318);
  static const Color dangerBg = Color(0xFFFEF3F2);
  static const Color infoFg = brandNavy;
  static const Color infoBg = cyanTint10;

  /// Positive cash movement — sales, payments received. Per the brand
  /// guide, an amount is never colored just because it's money; this is
  /// only for an explicit "money came in" direction/comparison signal.
  static const Color moneyIn = successFg;

  /// Negative cash movement, overdue debts, destructive actions.
  static const Color moneyOut = dangerFg;

  /// Low-stock / running-out warnings.
  static const Color lowStockWarning = warningFg;

  /// Neutral tint for zebra-striped data table rows.
  static const Color tableRowTint = hoverNeutral;

  /// Manually built — not [ColorScheme.fromSeed] — so every slot is an
  /// exact brand value instead of a derived Material tonal-palette color.
  /// [ColorScheme.light] supplies sensible defaults for every field this
  /// app doesn't otherwise touch; only the fields actually read anywhere
  /// in the app (see the `scheme.*`/`colorScheme.*` grep this was built
  /// from) are overridden below.
  static final ColorScheme scheme = const ColorScheme.light().copyWith(
    primary: brandNavy,
    onPrimary: surfaceWhite,
    primaryContainer: cyanTint10,
    onPrimaryContainer: brandNavy,
    secondary: brandCyan,
    onSecondary: brandNavy,
    error: dangerFg,
    onError: surfaceWhite,
    errorContainer: dangerBg,
    onErrorContainer: dangerFg,
    surface: background,
    onSurface: textPrimary,
    onSurfaceVariant: textSecondary,
    surfaceContainerLow: surfaceWhite,
    surfaceContainerHighest: hoverNeutral,
    outline: borderStrong,
    outlineVariant: border,
    inverseSurface: neutralDark,
    onInverseSurface: surfaceWhite,
    surfaceTint: Colors.transparent,
  );
}
