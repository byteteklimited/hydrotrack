import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hydrotrack/core/theme/app_theme.dart';
import 'package:hydrotrack/core/widgets/app_bottom_nav_bar.dart';

const _tabs = [
  AppBottomNavItem(icon: Icons.home_outlined, label: 'Home'),
  AppBottomNavItem(icon: Icons.factory_outlined, label: 'Production'),
  AppBottomNavItem(icon: Icons.inventory_2_outlined, label: 'Inventory'),
  AppBottomNavItem(icon: Icons.point_of_sale, label: 'Sales'),
  AppBottomNavItem(icon: Icons.receipt_long_outlined, label: 'Debts'),
  AppBottomNavItem(icon: Icons.more_horiz, label: 'More'),
];

void main() {
  testWidgets('six tabs fit a small phone with large text, lined up', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    int? tapped;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 640),
            textScaler: TextScaler.linear(1.4),
          ),
          child: Scaffold(
            bottomNavigationBar: AppBottomNavBar(
              items: _tabs,
              selectedIndex: 1,
              onSelect: (i) => tapped = i,
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    final iconRows = {
      for (final tab in _tabs) tester.getCenter(find.byIcon(tab.icon)).dy,
    };
    expect(iconRows, hasLength(1), reason: 'every icon at the same height');
    final labelRows = {
      for (final tab in _tabs) tester.getCenter(find.text(tab.label)).dy,
    };
    expect(labelRows, hasLength(1), reason: 'every label on one line');

    await tester.tap(find.text('Production'));
    expect(tapped, 1);
  });
}
