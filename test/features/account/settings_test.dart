import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hydrotrack/features/account/view/screens/settings_screen.dart';
import 'package:hydrotrack/features/admin/data/providers/admin_providers.dart';
import 'package:hydrotrack/features/auth/data/models/staff_user.dart';
import 'package:hydrotrack/features/auth/data/providers/auth_providers.dart';
import 'package:hydrotrack/features/auth/data/repositories/auth_repository.dart';
import 'package:hydrotrack/features/offline/data/providers/offline_providers.dart';
import 'package:hydrotrack/features/offline/data/services/offline_controller.dart';
import 'package:hydrotrack/features/offline/data/repositories/offline_store.dart';
import 'package:hydrotrack/features/organizations/data/models/organization.dart';
import 'package:hydrotrack/features/organizations/data/providers/organization_providers.dart';
import 'package:sembast/sembast_memory.dart';

import '../offline/offline_fixtures.dart';

/// Records profile changes; the current PIN/password is "482913".
class _FakeAuth implements AuthRepository {
  _FakeAuth({this.email});

  final String? email;
  final names = <String>[];
  final secrets = <String>[];

  @override
  String? get signInEmail => email;

  @override
  Future<void> updateFullName(String fullName) async => names.add(fullName);

  @override
  Future<void> changeSecret({
    required String identifier,
    required String current,
    required String next,
  }) async {
    if (current != '482913') throw StateError('Your current PIN is not right.');
    secrets.add('$identifier/$next');
  }

  @override
  Stream<void> get passwordRecoveries => const Stream.empty();

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

const _cashier = StaffUser(
  id: 'u1',
  fullName: 'Musa Ibrahim',
  role: StaffRole.cashier,
  phone: '08031234567',
);

Future<_FakeAuth> _pump(
  WidgetTester tester, {
  StaffUser user = _cashier,
  String? email,
}) async {
  tester.view.physicalSize = const Size(800, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final auth = _FakeAuth(email: email);
  final offline = OfflineController(
    store: SembastOfflineStore(
      database: newDatabaseFactoryMemory().openDatabase('settings.db'),
    ),
    api: FakeSyncApi(sampleSnapshot()),
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        authStateProvider.overrideWith((ref) => user),
        currentOrganizationProvider.overrideWith(
          (ref) => const Organization(id: 'org', name: 'Sunny Water'),
        ),
        isPlatformAdminProvider.overrideWith((ref) async => false),
        offlineControllerProvider.overrideWith((ref) => offline),
      ],
      child: const MaterialApp(home: SettingsScreen()),
    ),
  );
  await tester.pumpAndSettle();
  return auth;
}

void main() {
  testWidgets('staff rename themselves and change their PIN', (tester) async {
    final auth = await _pump(tester);
    expect(find.text('Change PIN'), findsWidgets);
    expect(find.textContaining('You sign in with 08031234567'), findsOneWidget);
    expect(find.text('Organization settings'), findsNothing);
    expect(find.text('Sign out'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).first, 'Musa Bello');
    await tester.tap(find.text('Save name'));
    await tester.pumpAndSettle();
    expect(auth.names, ['Musa Bello']);
    expect(find.text('Name saved'), findsOneWidget);
    // Let the message go, so the next one shows straight away.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(1), '111111');
    await tester.enterText(fields.at(2), '123456');
    await tester.enterText(fields.at(3), '123456');
    await tester.tap(find.widgetWithText(FilledButton, 'Change PIN'));
    await tester.pumpAndSettle();
    expect(find.text('Your current PIN is not right.'), findsOneWidget);
    expect(auth.secrets, isEmpty);

    await tester.enterText(fields.at(1), '482913');
    await tester.enterText(fields.at(3), '123450');
    await tester.tap(find.widgetWithText(FilledButton, 'Change PIN'));
    await tester.pumpAndSettle();
    expect(find.text("The PINs don't match"), findsOneWidget);

    await tester.enterText(fields.at(3), '123456');
    await tester.tap(find.widgetWithText(FilledButton, 'Change PIN'));
    await tester.pumpAndSettle();
    expect(auth.secrets, ['08031234567/123456']);
  });

  testWidgets('owners with an email change their password and reach '
      'organization settings', (tester) async {
    await _pump(
      tester,
      user: const StaffUser(
        id: 'o1',
        fullName: 'Aisha Bello',
        role: StaffRole.owner,
        phone: '',
      ),
      email: 'aisha@sunny.ng',
    );
    expect(find.text('Change password'), findsWidgets);
    expect(
      find.textContaining('You sign in with aisha@sunny.ng'),
      findsOneWidget,
    );
    expect(find.text('Organization settings'), findsOneWidget);
    expect(find.text('Plan and subscription'), findsOneWidget);
  });
}
