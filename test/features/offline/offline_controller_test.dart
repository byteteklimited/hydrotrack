import 'package:flutter_test/flutter_test.dart';
import 'package:hydrotrack/features/auth/data/models/staff_user.dart';
import 'package:hydrotrack/features/offline/data/models/offline_credential.dart';
import 'package:hydrotrack/features/offline/data/models/outbox_operation.dart';
import 'package:hydrotrack/features/offline/data/repositories/offline_store.dart';
import 'package:hydrotrack/features/offline/data/services/offline_controller.dart';
import 'package:sembast/sembast_memory.dart';

import 'offline_fixtures.dart';

const _cashier = StaffUser(
  id: cashierId,
  fullName: 'Carol Cashier',
  role: StaffRole.cashier,
  phone: '08031234567',
);

void main() {
  late FakeSyncApi api;
  late OfflineStore store;

  OfflineController newController() =>
      OfflineController(store: store, api: api);

  setUp(() {
    api = FakeSyncApi(
      sampleSnapshot(
        cashierCredential: OfflineCredential.create(
          '482913',
          iterations: testIterations,
        ),
      ),
    );
    store = SembastOfflineStore(
      database: newDatabaseFactoryMemory().openDatabase('offline.db'),
    );
  });

  Future<OfflineController> setUpDevice() async {
    final controller = newController();
    await controller.ready;
    await controller.setUp(tenantId: tenantId, name: 'Front desk');
    return controller;
  }

  test(
    'stops recording once the subscription has ended, until it is renewed',
    () async {
      final now = DateTime.now();
      api.serverData = sampleSnapshot(
        subscription: subscriptionJson(
          status: 'expired',
          accessEndsAt: now.subtract(const Duration(days: 1)),
        ),
      );
      final controller = await setUpDevice();
      await expectLater(
        controller.record(
          type: OperationType.sale,
          payload: salePayload(),
          actor: _cashier,
        ),
        throwsA(isA<StateError>()),
      );
      expect(controller.state.outbox, isEmpty, reason: 'nothing queued');

      api.serverData = sampleSnapshot(
        subscription: subscriptionJson(
          status: 'active',
          accessEndsAt: now.add(const Duration(days: 30)),
        ),
      );
      await controller.sync();
      await controller.record(
        type: OperationType.sale,
        payload: salePayload(),
        actor: _cashier,
      );
      expect(controller.state.outbox, isNotEmpty, reason: 'renewed');
    },
  );

  test('the subscription is kept with the device copy', () async {
    final now = DateTime.now();
    api.serverData = sampleSnapshot(
      subscription: subscriptionJson(
        status: 'trial',
        accessEndsAt: now.add(const Duration(days: 10)),
      ),
    );
    final controller = await setUpDevice();
    final restarted = newController();
    await restarted.ready;
    expect(restarted.currentSnapshot!.subscription?['status'], 'trial');
    expect(controller.currentSnapshot!.copy().subscription, isNotNull);
  });

  test('setting up downloads the organization onto the device', () async {
    final controller = await setUpDevice();
    expect(controller.state.isReadyFor(tenantId), isTrue);
    expect(controller.currentSnapshot!.rows('customers'), hasLength(1));
  });

  test(
    'records made offline survive a restart and sync once back online',
    () async {
      final controller = await setUpDevice();
      api.offline = true;
      await controller.record(
        type: OperationType.sale,
        payload: salePayload(),
        actor: _cashier,
      );
      await controller.record(
        type: OperationType.sale,
        payload: salePayload(bags: 5),
        actor: _cashier,
      );
      await controller.sync();
      expect(
        controller.state.pending,
        hasLength(2),
        reason: 'kept while offline',
      );
      expect(
        controller.state.lastSyncError,
        isNull,
        reason: 'no internet is not an error',
      );
      expect(
        controller.currentSnapshot!.row(
          'stock_items',
          sachetId,
        )!['quantity_on_hand'],
        85,
      );

      // App closed and reopened, still offline: nothing lost.
      final reopened = newController();
      await reopened.ready;
      expect(reopened.state.pending, hasLength(2));
      expect(reopened.currentSnapshot!.rows('sales'), hasLength(2));

      api.offline = false;
      await reopened.sync();
      expect(api.received, hasLength(2));
      expect(reopened.state.outbox, isEmpty);
      expect(
        reopened.serverIdFor(api.received.first),
        'srv-${api.received.first}',
      );
    },
  );

  test('records are sent in the order they were made', () async {
    final controller = await setUpDevice();
    api.offline = true;
    final first = await controller.record(
      type: OperationType.sale,
      payload: salePayload(),
      actor: _cashier,
    );
    final second = await controller.record(
      type: OperationType.expense,
      payload: {
        'date': '2026-11-01',
        'category': 'other',
        'description': 'x',
        'amount': 1,
        'method': 'cash',
      },
      actor: _cashier,
    );
    api.offline = false;
    await controller.sync();
    expect(api.received, [first.opId, second.opId]);
  });

  test('a refused record is kept with the reason and can be retried', () async {
    final controller = await setUpDevice();
    api.refuse.add('sale');
    final op = await controller.record(
      type: OperationType.sale,
      payload: salePayload(),
      actor: _cashier,
    );
    await controller.sync();
    final kept = controller.state.rejected.single;
    expect(kept.opId, op.opId);
    expect(kept.error, 'Not allowed');

    api.refuse.clear();
    await controller.retry(op.opId);
    expect(controller.state.outbox, isEmpty);
  });

  test('a fresh download keeps records still waiting on top', () async {
    final controller = await setUpDevice();
    api.stopWith = 'This device was switched off by an admin';
    await controller.record(
      type: OperationType.sale,
      payload: salePayload(bags: 30),
      actor: _cashier,
    );
    await controller.sync();
    expect(controller.state.pending, hasLength(1));
    expect(controller.state.lastSyncError, contains('switched off'));
    expect(
      controller.currentSnapshot!.row(
        'stock_items',
        sachetId,
      )!['quantity_on_hand'],
      70,
    );
  });

  test('turning off is refused while records are waiting', () async {
    final controller = await setUpDevice();
    api.offline = true;
    await controller.record(
      type: OperationType.sale,
      payload: salePayload(),
      actor: _cashier,
    );
    expect(controller.turnOff, throwsStateError);
  });

  group('offline sign-in', () {
    test('lets a member in with their PIN', () async {
      final controller = await setUpDevice();
      final result = await controller.signIn(
        identifier: '08031234567',
        secret: '482913',
      );
      expect((result as OfflineSignInSuccess).member.userId, cashierId);
    });

    test('refuses a wrong PIN', () async {
      final controller = await setUpDevice();
      final result = await controller.signIn(
        identifier: '08031234567',
        secret: '000000',
      );
      expect(
        (result as OfflineSignInRefused).reason,
        OfflineSignInFailure.incorrect,
      );
    });

    test('refuses a deactivated member even with the right PIN', () async {
      final controller = await setUpDevice();
      final result = await controller.signIn(
        identifier: '08099999999',
        secret: '111111',
      );
      expect(
        (result as OfflineSignInRefused).reason,
        OfflineSignInFailure.deactivated,
      );
    });

    test('explains when someone has no offline check yet', () async {
      api.serverData = sampleSnapshot();
      final controller = await setUpDevice();
      final result = await controller.signIn(
        identifier: '08031234567',
        secret: '482913',
      );
      expect(
        (result as OfflineSignInRefused).reason,
        OfflineSignInFailure.noOfflineCheck,
      );
    });

    test('is not possible on a device that was never set up', () async {
      final controller = newController();
      await controller.ready;
      final result = await controller.signIn(
        identifier: '08031234567',
        secret: '482913',
      );
      expect(
        (result as OfflineSignInRefused).reason,
        OfflineSignInFailure.deviceNotSetUp,
      );
    });
  });
}
