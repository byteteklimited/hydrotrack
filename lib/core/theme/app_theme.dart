import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_spacing.dart';
import 'app_typography.dart';
import 'brand_palette.dart';

/// Single source of the app's [ThemeData]. Light theme only — this is a
/// factory-floor app used in daylight; dark theme is out of scope until
/// asked for.
class AppTheme {
  AppTheme._();

  /// HydroTrack's own colors (sign-in, splash, outside an organization).
  static ThemeData get light => forBrand(BrandPalette.hydrotrack);

  /// The app in an organization's colors.
  static ThemeData forBrand(BrandPalette brand) {
    final scheme = brand.scheme;
    final textTheme = AppTypography.textTheme;

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      extensions: [brand],
      textTheme: textTheme,
      scaffoldBackgroundColor: AppColors.background,
      splashFactory: InkSparkle.splashFactory,
      // Kills Material 3's automatic color-tint-on-elevation everywhere —
      // every surface stays the exact flat color it's given, not a
      // tinted-toward-primary variant of it.
      splashColor: brand.accentTint,
      highlightColor: brand.accentTint.withValues(alpha: 0.5),
      hoverColor: AppColors.hoverNeutral,
      focusColor: brand.accentTint,

      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 1,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: AppColors.textPrimary,
        ),
      ),

      cardTheme: CardThemeData(
        elevation: 0,
        color: AppColors.surfaceWhite,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.panel),
          side: const BorderSide(color: AppColors.border),
        ),
        margin: EdgeInsets.zero,
      ),

      // A real outlined field — the rest-state border is `borderStrong`,
      // not the decorative `border` token, since the brief's own rule
      // requires >=3:1 for an input's boundary to actually register as
      // one; `border` alone measures ~1.25:1 and was never meant for
      // this. A 2px navy rule on focus, radius 4 per the "inputs/chips"
      // bucket. Not filled: panels are already white, and a filled
      // field on a white panel would have nothing to contrast against.
      inputDecorationTheme: InputDecorationTheme(
        filled: false,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide: const BorderSide(color: AppColors.borderStrong),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide: const BorderSide(color: AppColors.borderStrong),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide: BorderSide(color: brand.primaryText, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide: const BorderSide(color: AppColors.dangerFg),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide: const BorderSide(color: AppColors.dangerFg, width: 2),
        ),
        labelStyle: textTheme.bodyMedium?.copyWith(
          color: AppColors.textSecondary,
        ),
        floatingLabelStyle: textTheme.bodySmall?.copyWith(
          color: AppColors.textSecondary,
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: AppColors.textTertiary,
        ),
        helperStyle: textTheme.bodySmall?.copyWith(
          color: AppColors.textSecondary,
        ),
        prefixIconColor: AppColors.textSecondary,
        suffixIconColor: AppColors.textSecondary,
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return brand.primaryDisabled;
            }
            if (states.contains(WidgetState.pressed)) {
              return brand.primaryPressed;
            }
            if (states.contains(WidgetState.hovered)) {
              return brand.primaryHover;
            }
            return brand.primary;
          }),
          foregroundColor: WidgetStatePropertyAll(brand.onPrimary),
          elevation: const WidgetStatePropertyAll(0),
          minimumSize: const WidgetStatePropertyAll(Size(64, 40)),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.button),
            ),
          ),
          textStyle: WidgetStatePropertyAll(textTheme.labelLarge),
        ),
      ),

      // The app's actual primary button (AppButtonVariant.primary →
      // FilledButton) — same hover/pressed states as ElevatedButtonTheme
      // above, since this is the one every "Record sale"/"Sign in"/etc.
      // button in the app actually uses.
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return brand.primaryDisabled;
            }
            if (states.contains(WidgetState.pressed)) {
              return brand.primaryPressed;
            }
            if (states.contains(WidgetState.hovered)) {
              return brand.primaryHover;
            }
            return brand.primary;
          }),
          foregroundColor: WidgetStatePropertyAll(brand.onPrimary),
          elevation: const WidgetStatePropertyAll(0),
          minimumSize: const WidgetStatePropertyAll(Size(64, 40)),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.button),
            ),
          ),
          textStyle: WidgetStatePropertyAll(textTheme.labelLarge),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: brand.primaryText,
          side: const BorderSide(color: AppColors.borderStrong),
          minimumSize: const Size(64, 40),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.button),
          ),
          textStyle: textTheme.labelLarge,
          overlayColor: brand.accentTint,
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: brand.primaryText,
          minimumSize: const Size(64, 40),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.button),
          ),
          textStyle: textTheme.labelLarge,
          overlayColor: brand.accentTint,
        ),
      ),

      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          foregroundColor: AppColors.textSecondary,
          selectedForegroundColor: brand.primaryText,
          selectedBackgroundColor: brand.accentTint,
          side: const BorderSide(color: AppColors.border),
          textStyle: textTheme.labelLarge,
        ),
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surfaceWhite,
        surfaceTintColor: Colors.transparent,
        indicatorColor: brand.accentTint,
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.button),
        ),
        elevation: 1,
        height: 64,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? brand.primaryText : AppColors.textSecondary,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return textTheme.labelMedium?.copyWith(
            color: selected ? brand.primaryText : AppColors.textSecondary,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          );
        }),
      ),

      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: AppColors.surfaceWhite,
        indicatorColor: brand.accentTint,
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.button),
        ),
        useIndicator: true,
        selectedIconTheme: IconThemeData(color: brand.primaryText),
        unselectedIconTheme: const IconThemeData(
          color: AppColors.textSecondary,
        ),
        selectedLabelTextStyle: textTheme.labelLarge?.copyWith(
          color: brand.primaryText,
        ),
        unselectedLabelTextStyle: textTheme.labelLarge?.copyWith(
          color: AppColors.textSecondary,
        ),
      ),

      tabBarTheme: TabBarThemeData(
        labelColor: brand.primaryText,
        unselectedLabelColor: AppColors.textSecondary,
        labelStyle: textTheme.labelLarge,
        unselectedLabelStyle: textTheme.labelLarge,
        indicatorColor: brand.primaryText,
        dividerColor: AppColors.border,
      ),

      chipTheme: ChipThemeData(
        backgroundColor: AppColors.hoverNeutral,
        side: const BorderSide(color: AppColors.border),
        labelStyle: textTheme.labelMedium?.copyWith(
          color: AppColors.textPrimary,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
        ),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surfaceWhite,
        surfaceTintColor: Colors.transparent,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sheet),
        ),
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: AppColors.textPrimary,
        ),
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: AppColors.textPrimary,
        ),
      ),

      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: AppColors.neutralDark,
          borderRadius: BorderRadius.circular(AppRadius.input),
        ),
        textStyle: textTheme.bodySmall?.copyWith(color: Colors.white),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        waitDuration: AppDurations.normal,
      ),

      dividerTheme: const DividerThemeData(
        color: AppColors.divider,
        thickness: 1,
        space: 1,
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.neutralDark,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: AppColors.surfaceWhite,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
        ),
      ),
    );
  }
}
