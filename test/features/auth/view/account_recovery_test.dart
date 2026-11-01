import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hydrotrack/core/constants/app_routes.dart';
import 'package:hydrotrack/features/auth/data/providers/auth_providers.dart';
import 'package:hydrotrack/features/auth/data/repositories/auth_repository.dart';
import 'package:hydrotrack/features/auth/view/screens/forgot_password_screen.dart';
import 'package:hydrotrack/features/auth/view/screens/login_screen.dart';
import 'package:hydrotrack/features/auth/view/screens/reset_pin_screen.dart';

/// Records reset requests; no network.
class _RecordingAuth implements AuthRepository {
  final pinResets = <String>[];
  final passwordResets = <String>[];

  @override
  Future<String> resetPinWithCode({
    required String code,
    required String pin,
  }) async {
    pinResets.add('$code/$pin');
    throw Exception('stop here');
  }

  @override
  Future<void> sendPasswordReset(String email) async =>
      passwordResets.add(email);

  @override
  Stream<void> get passwordRecoveries => const Stream.empty();

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

Future<_RecordingAuth> _pumpLogin(WidgetTester tester) async {
  tester.view.physicalSize = const Size(800, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final auth = _RecordingAuth();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [authRepositoryProvider.overrideWithValue(auth)],
      child: MaterialApp(
        routes: {
          '/': (_) => const LoginScreen(),
          AppRoutes.resetPin: (_) => const ResetPinScreen(),
          AppRoutes.forgotPassword: (_) => const ForgotPasswordScreen(),
        },
      ),
    ),
  );
  return auth;
}

void main() {
  testWidgets('"Forgot your PIN?" opens the reset form, which checks the '
      'PINs match before sending', (tester) async {
    final auth = await _pumpLogin(tester);
    await tester.tap(find.text('Forgot your PIN?'));
    await tester.pumpAndSettle();
    expect(find.text('Reset your PIN'), findsOneWidget);

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'abcd2345xy');
    await tester.enterText(fields.at(1), '123456');
    await tester.enterText(fields.at(2), '654321');
    await tester.tap(find.text('Set new PIN and sign in'));
    await tester.pumpAndSettle();
    expect(find.text("PINs don't match"), findsOneWidget);
    expect(auth.pinResets, isEmpty);

    await tester.enterText(fields.at(2), '123456');
    await tester.tap(find.text('Set new PIN and sign in'));
    await tester.pumpAndSettle();
    expect(auth.pinResets, ['ABCD2345XY/123456']);
  });

  testWidgets('"Forgot your password?" sends a reset link and says so', (
    tester,
  ) async {
    final auth = await _pumpLogin(tester);
    await tester.tap(find.text('Forgot your password?'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField), 'owner@sunny.ng');
    await tester.tap(find.text('Send reset link'));
    await tester.pumpAndSettle();
    expect(auth.passwordResets, ['owner@sunny.ng']);
    expect(find.textContaining('a reset link is on its way'), findsOneWidget);
  });
}
