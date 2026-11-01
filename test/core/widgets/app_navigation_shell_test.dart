import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hydrotrack/core/widgets/app_nav_section.dart';
import 'package:hydrotrack/core/widgets/app_navigation_shell.dart';
import 'package:hydrotrack/features/auth/data/models/staff_user.dart';
import 'package:hydrotrack/features/auth/data/providers/auth_providers.dart';
import 'package:hydrotrack/features/organizations/data/models/organization.dart';
import 'package:hydrotrack/features/organizations/data/providers/organization_providers.dart';

/// The owner has the longest "More" list (it includes Organization), so
/// it's the case most likely to overflow a short window.
Future<void> _openMoreAsOwner(WidgetTester tester, Size window) async {
  tester.view.physicalSize = window;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authStateProvider.overrideWith(
          (ref) => const StaffUser(
            id: 'owner',
            fullName: 'Demo Owner',
            role: StaffRole.owner,
            phone: '',
          ),
        ),
        currentOrganizationProvider.overrideWith(
          (ref) => const Organization(id: 'org', name: 'Demo Water Factory'),
        ),
      ],
      child: MaterialApp(
        home: AppNavigationShell(
          pageBuilder: (AppSection section) => Text(section.label),
        ),
      ),
    ),
  );
  await tester.tap(find.text('More').last);
  await tester.pumpAndSettle();
}

void main() {
  for (final (name, window) in [
    ('short desktop window', const Size(1280, 640)),
    ('small phone', const Size(360, 560)),
  ]) {
    testWidgets(
      '"More" sheet lists every section without overflow on a $name',
      (tester) async {
        await _openMoreAsOwner(tester, window);

        expect(tester.takeException(), isNull);
        await tester.scrollUntilVisible(
          find.text('Organization'),
          50,
          scrollable: find.byType(Scrollable).last,
        );
        expect(find.text('Organization'), findsOneWidget);
      },
    );
  }
}
