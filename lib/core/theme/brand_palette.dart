import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'app_colors.dart';

/// An organization's brand colors and everything derived from them, so a
/// screen never needs to know which organization it's in: read
/// `context.brand`. Built from a main and an accent color; anything
/// derived is adjusted to stay readable (WCAG 2.1 contrast), whatever the
/// owner picks. HydroTrack's own navy and cyan are [hydrotrack].
@immutable
class BrandPalette extends ThemeExtension<BrandPalette> {
  BrandPalette({required this.primary, required this.accent})
    : primaryText = readableOn(primary, AppColors.surfaceWhite),
      onPrimary = textOn(primary),
      primaryHover = _shift(primary, 0.08),
      primaryPressed = _shift(primary, -0.14),
      primaryDisabled = primary.withValues(alpha: 0.38),
      accentTint = accent.withValues(alpha: _tintAlpha),
      accentGlow = accent.withValues(alpha: _glowAlpha);

  static final BrandPalette hydrotrack = BrandPalette(
    primary: AppColors.brandNavy,
    accent: AppColors.brandCyan,
  );

  /// Text needs this much contrast against its background (WCAG AA).
  static const minTextContrast = 4.5;
  static const _tintAlpha = 0.10;
  static const _glowAlpha = 0.25;

  /// Buttons, the active menu item, focus rings.
  final Color primary;

  /// Washes behind selected items, chart highlights — never text.
  final Color accent;

  /// [primary], darkened if needed, for text and icons on white.
  final Color primaryText;

  /// Text and icons on a [primary] background.
  final Color onPrimary;
  final Color primaryHover;
  final Color primaryPressed;
  final Color primaryDisabled;

  /// A light wash of [accent] for selected backgrounds.
  final Color accentTint;
  final Color accentGlow;

  /// WCAG 2.1 contrast ratio between two colors (1–21).
  static double contrast(Color a, Color b) {
    final la = a.computeLuminance();
    final lb = b.computeLuminance();
    return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
  }

  /// White or near-black, whichever reads better on [background].
  static Color textOn(Color background) =>
      contrast(background, AppColors.surfaceWhite) >=
          contrast(background, AppColors.textPrimary)
      ? AppColors.surfaceWhite
      : AppColors.textPrimary;

  /// [color] darkened step by step until it reads on [background].
  static Color readableOn(Color color, Color background) {
    var hsl = HSLColor.fromColor(color);
    var result = color;
    while (contrast(result, background) < minTextContrast &&
        hsl.lightness > 0) {
      hsl = hsl.withLightness(math.max(0, hsl.lightness - 0.04));
      result = hsl.toColor();
    }
    return result;
  }

  /// Lighter (+) or darker (−) by [amount] of lightness.
  static Color _shift(Color color, double amount) {
    final hsl = HSLColor.fromColor(color);
    return hsl
        .withLightness((hsl.lightness + amount).clamp(0.0, 1.0))
        .toColor();
  }

  /// `#RRGGBB` → color; null when it isn't one.
  static Color? parseHex(String? hex) {
    final match = RegExp(r'^#?([0-9a-fA-F]{6})$').firstMatch(hex?.trim() ?? '');
    if (match == null) return null;
    return Color(0xFF000000 | int.parse(match.group(1)!, radix: 16));
  }

  /// Color → `#RRGGBB`.
  static String toHex(Color color) =>
      '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

  /// The scheme Material widgets read, from this palette.
  ColorScheme get scheme => AppColors.scheme.copyWith(
    primary: primary,
    onPrimary: onPrimary,
    primaryContainer: accentTint,
    onPrimaryContainer: primaryText,
    secondary: accent,
    onSecondary: textOn(accent),
  );

  @override
  BrandPalette copyWith({Color? primary, Color? accent}) => BrandPalette(
    primary: primary ?? this.primary,
    accent: accent ?? this.accent,
  );

  @override
  BrandPalette lerp(BrandPalette? other, double t) {
    if (other == null) return this;
    return BrandPalette(
      primary: Color.lerp(primary, other.primary, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is BrandPalette &&
      other.primary == primary &&
      other.accent == accent;

  @override
  int get hashCode => Object.hash(primary, accent);
}

extension BrandContext on BuildContext {
  /// The current organization's colors (HydroTrack's outside one).
  BrandPalette get brand =>
      Theme.of(this).extension<BrandPalette>() ?? BrandPalette.hydrotrack;
}
