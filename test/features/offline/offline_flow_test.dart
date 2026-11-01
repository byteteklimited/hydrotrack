import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hydrotrack/core/utils/network_error.dart';
import 'package:hydrotrack/features/auth/data/models/staff_user.dart';
import 'package:hydrotrack/features/auth/data/providers/auth_providers.dart';
import 'package:hydrotrack/features/auth/data/repositories/auth_repository.dart';
import 'package:hydrotrack/features/auth/data/repositories/sign_in_result.dart';
import 'package:hydrotrack/features/auth/view/screens/login_screen.dart';
import 'package:hydrotrack/features/offline/data/models/offline_credential.dart';
import 'package:hydrotrack/features/offline/data/providers/offline_providers.dart';
import 'package:hydrotrack/features/offline/data/repositories/offline_store.dart';
import 'package:hydrotrack/features/offline/data/services/offline_context.dart';
import 'package:hydrotrack/features/offline/data/services/offline_controller.dart';
import 'package:hydrotrack/features/organizations/data/providers/organization_providers.dart';
import 'package:hydrotrack/features/sales/data/models/sale.dart';
import 'package:hydrotrack/features/sales/data/repositories/offline_sales_repository.dart';
import 'package:hydrotrack/features/sales/data/repositories/sales_repository.dart';
import 'package:sembast/sembast_memory.dart';

import 'offline_fixtures.dart';

/// No internet: every sign-in attempt can't reach the server.
class _NoInternetAuth implements AuthRepository {
  @override
  Future<SignInResult> signIn({
    required String identifier,
    required String secret,
  }) async => const SignInFailure(SignInFailureReason.noConnection);

  @override
  bool get hasSession => false;

  @override
  String? get signedInUserId => null;

  @override
  Stream<void> get passwordRecoveries => const Stream.empty();

  @override
  Future<void> signOut() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

/// The server, unreachable.
class _UnreachableSales implements SalesRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('should not be called');
}

void main() {
  late FakeSyncApi api;
  late OfflineController controller;

  setUp(() async {
    api = FakeSyncApi(
      sampleSnapshot(
        cashierCredential: OfflineCredential.create(
          '482913',
          iterations: testIterations,
        ),
      ),
    );
    controller = OfflineController(
      store: SembastOfflineStore(
        database: newDatabaseFactoryMemory().openDatabase('flow.db'),
      ),
      api: api,
    );
    await controller.ready;
    await controller.setUp(tenantId: tenantId, name: 'Front desk');
    api.offline = true;
  });

  test(
    'a cashier signs in offline and lands in the device organization',
    () async {
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(_NoInternetAuth()),
          offlineControllerProvider.overrideWith((ref) => controller),
        ],
      );
      addTearDown(container.dispose);

      final outcome = await container
          .read(signInControllerProvider.notifier)
          .signIn(identifier: '08031234567', secret: '482913');

      expect(outcome, SignInOutcome.offline);
      expect(container.read(currentOrganizationProvider)?.name, 'Sunny Water');
      expect(container.read(authStateProvider)?.role, StaffRole.cashier);
      expect(container.read(offlineContextProvider), isNotNull);
    },
  );

  test('a wrong PIN offline is refused with the usual message', () async {
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(_NoInternetAuth()),
        offlineControllerProvider.overrideWith((ref) => controller),
      ],
    );
    addTearDown(container.dispose);

    final outcome = await container
        .read(signInControllerProvider.notifier)
        .signIn(identifier: '08031234567', secret: '000000');

    expect(outcome, isNull);
    expect(
      signInErrorMessage(container.read(signInControllerProvider).error),
      contains('incorrect'),
    );
  });

  group('sales offline', () {
    late OfflineSalesRepository sales;

    setUp(() {
      sales = OfflineSalesRepository(
        _UnreachableSales(),
        OfflineContext(
          controller: controller,
          actor: const StaffUser(
            id: cashierId,
            fullName: 'Carol Cashier',
            role: StaffRole.cashier,
            phone: '08031234567',
          ),
          isConnected: () => false,
        ),
      );
    });

    test('a sale recorded offline shows in the list straight away', () async {
      final sale = Sale.fromJson({
        ...sampleSnapshot().rows('sales').firstOrNull ?? {},
        'id': 'draft',
        'date_time': DateTime.now().toIso8601String(),
        'customer_type': 'walk_in',
        'customer_name': null,
        'total': 4000,
        'amount_paid': 4000,
        'payment_method': 'cash',
        'balance': 0,
        'sale_lines': [
          {
            'product_id': sachetProductId,
            'products': {'name': '50cl Sachet', 'unit': 'bags'},
            'quantity': 10,
            'unit_price': 400,
          },
        ],
      });
      final saved = await sales.recordSale(sale);
      expect(saved.total, 4000);
      expect((await sales.fetchSales()).single.id, saved.id);
      expect(controller.state.pending, hasLength(1));
    });

    test('voiding needs internet, with a clear message', () async {
      expect(
        () => sales.voidSale(saleId: 'any', reason: 'x'),
        throwsA(isA<NeedsInternetException>()),
      );
    });
  });
}
