import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hydrotrack/core/widgets/app_nav_section.dart';
import 'package:hydrotrack/features/auth/data/models/staff_user.dart';
import 'package:hydrotrack/features/auth/data/providers/auth_providers.dart';
import 'package:hydrotrack/features/organizations/data/models/organization.dart';
import 'package:hydrotrack/features/organizations/data/providers/organization_providers.dart';
import 'package:hydrotrack/features/reports/view/screens/app_home_screen.dart';

import 'test_locations.dart';

/// Opens every section an owner can reach. There's no backend in tests,
/// so each screen shows its loading/error state — this catches layout
/// crashes (like the one Inventory had) in the screens' own structure.
void main() {
  final config = RoleNavConfig.forRole(StaffRole.owner);

  for (final (name, window) in [
    ('desktop', const Size(1400, 900)),
    ('phone', const Size(390, 800)),
  ]) {
    for (final section in [...config.primary, ...config.overflow]) {
      testWidgets('${section.label} opens without errors on $name', (
        tester,
      ) async {
        tester.view.physicalSize = window;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              ...testLocationOverrides,
              authStateProvider.overrideWith(
                (ref) => const StaffUser(
                  id: 'owner',
                  fullName: 'Demo Owner',
                  role: StaffRole.owner,
                  phone: '',
                ),
              ),
              currentOrganizationProvider.overrideWith(
                (ref) =>
                    const Organization(id: 'org', name: 'Demo Water Factory'),
              ),
            ],
            child: const MaterialApp(home: AppHomeScreen()),
          ),
        );
        await tester.pumpAndSettle();

        if (config.overflow.contains(section)) {
          await tester.tap(find.text('More').last);
          await tester.pumpAndSettle();
        }
        await tester.tap(find.text(section.label).last);
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      });
    }
  }
}
