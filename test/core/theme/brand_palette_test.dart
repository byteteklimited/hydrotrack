import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hydrotrack/core/theme/app_colors.dart';
import 'package:hydrotrack/core/theme/app_theme.dart';
import 'package:hydrotrack/core/theme/brand_palette.dart';
import 'package:hydrotrack/core/theme/brand_swatches.dart';
import 'package:hydrotrack/core/utils/formatters.dart';
import 'package:hydrotrack/features/organizations/data/models/organization.dart';
import 'package:hydrotrack/features/organizations/view/widgets/brand_preview.dart';

void main() {
  test('hex codes read and write both ways', () {
    expect(BrandPalette.parseHex('#1d4ed8'), const Color(0xFF1D4ED8));
    expect(BrandPalette.parseHex('1D4ED8'), const Color(0xFF1D4ED8));
    expect(BrandPalette.parseHex('#12345'), isNull);
    expect(BrandPalette.toHex(const Color(0xFF0A2E94)), '#0A2E94');
  });

  test('HydroTrack navy contrasts with white as the design system says', () {
    expect(
      BrandPalette.contrast(AppColors.brandNavy, AppColors.surfaceWhite),
      greaterThan(BrandPalette.minTextContrast),
    );
    expect(BrandPalette.hydrotrack.primaryText, AppColors.brandNavy);
  });

  test('a light main color is darkened for text, and gets dark text on it', () {
    final yellow = BrandPalette(
      primary: const Color(0xFFFACC15),
      accent: const Color(0xFF02BDFB),
    );
    expect(
      BrandPalette.contrast(yellow.primaryText, AppColors.surfaceWhite),
      greaterThanOrEqualTo(BrandPalette.minTextContrast),
    );
    expect(yellow.onPrimary, AppColors.textPrimary);
    expect(BrandPalette.hydrotrack.onPrimary, AppColors.surfaceWhite);
  });

  test('every ready-made main color takes white text', () {
    for (final color in BrandSwatches.main) {
      expect(
        BrandPalette.textOn(color),
        AppColors.surfaceWhite,
        reason: BrandPalette.toHex(color),
      );
    }
  });

  test(
    'an organization wears its colors, HydroTrack\'s until it sets some',
    () {
      const plain = Organization(id: 'o', name: 'Sunny water ltd');
      expect(plain.palette, BrandPalette.hydrotrack);
      expect(plain.initials, 'SW');
      final branded = Organization.fromJson({
        'id': 'o',
        'name': 'Sunny Water',
        'brand_primary': '#15803D',
        'brand_accent': '#FACC15',
      });
      expect(branded.palette.primary, const Color(0xFF15803D));
      expect(branded.toJson()['brand_accent'], '#FACC15');
      final theme = AppTheme.forBrand(branded.palette);
      expect(theme.colorScheme.primary, const Color(0xFF15803D));
      expect(theme.extension<BrandPalette>(), branded.palette);
    },
  );

  test('file names use the organization', () {
    expect(fileSlug('Sunny Water Ltd.'), 'sunny-water-ltd');
    expect(fileSlug('  '), 'records');
  });

  testWidgets('the preview draws any colors without errors', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BrandPreview(
            palette: BrandPalette(
              primary: const Color(0xFFFACC15),
              accent: const Color(0xFFF472B6),
            ),
            name: 'Sunny Water',
          ),
        ),
      ),
    );
    expect(find.text('Sunny Water'), findsOneWidget);
    expect(find.textContaining('a little darker'), findsOneWidget);
  });
}
