import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hydrotrack/core/constants/app_routes.dart';
import 'package:hydrotrack/core/widgets/app_navigation_shell.dart';
import 'package:hydrotrack/features/auth/data/models/staff_user.dart';
import 'package:hydrotrack/features/auth/data/providers/auth_providers.dart';
import 'package:hydrotrack/features/auth/data/repositories/auth_repository.dart';
import 'package:hydrotrack/features/auth/data/repositories/sign_in_result.dart';
import 'package:hydrotrack/features/auth/view/screens/login_screen.dart';
import 'package:hydrotrack/features/inventory/data/providers/inventory_providers.dart';
import 'package:hydrotrack/features/organizations/data/models/organization.dart';
import 'package:hydrotrack/features/organizations/data/providers/organization_providers.dart';
import 'package:hydrotrack/features/reports/view/screens/app_home_screen.dart';
import 'package:hydrotrack/main.dart';

/// Signed out, with no network behind it.
class _SignedOutAuth implements AuthRepository {
  @override
  bool get hasSession => false;

  @override
  Future<void> signOut() async {}

  @override
  Future<SignInResult> signIn({
    required String identifier,
    required String secret,
  }) => throw UnimplementedError();

  @override
  Future<SignUpOutcome> signUp({
    required String fullName,
    required String email,
    required String password,
  }) => throw UnimplementedError();

  @override
  Future<String> createAccountFromInvite({
    required String code,
    required String pin,
  }) => throw UnimplementedError();
}

void main() {
  testWidgets('reloading the web app on #/home starts at sign-in, not Home', (
    tester,
  ) async {
    tester.platformDispatcher.defaultRouteNameTestValue = AppRoutes.home;
    addTearDown(tester.platformDispatcher.clearDefaultRouteNameTestValue);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [authRepositoryProvider.overrideWithValue(_SignedOutAuth())],
        child: const HydroTrackApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(AppHomeScreen), findsNothing);
  });

  testWidgets('signing out from Inventory goes to sign-in without errors', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(_SignedOutAuth()),
          stockItemsProvider.overrideWith((ref) async => const []),
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
          routes: {
            '/': (_) => const AppHomeScreen(),
            AppRoutes.login: (_) => const Text('Sign-in screen'),
          },
        ),
      ),
    );
    await tester.tap(find.text('Inventory').first);
    await tester.pumpAndSettle();

    final ref = tester.element(find.byType(AppNavigationShell)) as WidgetRef;
    final context = tester.element(find.byType(AppNavigationShell));
    signOutAndReturnToLogin(context, ref);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Sign-in screen'), findsOneWidget);
  });
}
