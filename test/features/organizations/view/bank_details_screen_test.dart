import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hydrotrack/features/organizations/data/models/bank_details.dart';
import 'package:hydrotrack/features/organizations/data/models/membership.dart';
import 'package:hydrotrack/features/organizations/data/models/organization.dart';
import 'package:hydrotrack/features/organizations/data/providers/organization_providers.dart';
import 'package:hydrotrack/features/organizations/data/repositories/organization_repository.dart';
import 'package:hydrotrack/features/organizations/view/widgets/debt_reminders_card.dart';

/// Records bank-detail saves; nothing else is used by these screens.
class _FakeOrganizations implements OrganizationRepository {
  final saved = <BankDetails?>[];

  @override
  Future<Organization> updateBankDetails({
    required String organizationId,
    required BankDetails? details,
  }) async {
    saved.add(details);
    return Organization(
      id: organizationId,
      name: 'Demo Water Factory',
      bankDetails: details,
    );
  }

  @override
  Future<List<Membership>> fetchMyMemberships() async => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

/// Form fields in order: bank, account number, account name.
Finder _field(int index) => find.byType(TextFormField).at(index);

const _organization = Organization(id: 'org', name: 'Demo Water Factory');

Future<_FakeOrganizations> _pumpCard(
  WidgetTester tester, {
  Organization organization = _organization,
}) async {
  final repository = _FakeOrganizations();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        organizationRepositoryProvider.overrideWithValue(repository),
        currentOrganizationProvider.overrideWith((ref) => organization),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: Consumer(
            builder: (context, ref, _) => DebtRemindersCard(
              organization: ref.watch(currentOrganizationProvider)!,
            ),
          ),
        ),
      ),
    ),
  );
  return repository;
}

void main() {
  testWidgets('explains the schedule and asks for bank details', (
    tester,
  ) async {
    await _pumpCard(tester);
    expect(find.textContaining('every 7 days'), findsOneWidget);
    expect(find.textContaining('No bank details yet'), findsOneWidget);
    expect(find.text('Add bank details'), findsOneWidget);
  });

  testWidgets('saving bank details shows them on the card', (tester) async {
    final repository = await _pumpCard(tester);
    await tester.tap(find.text('Add bank details'));
    await tester.pumpAndSettle();

    await tester.enterText(_field(0), 'GTBank');
    await tester.enterText(_field(1), '0123456789');
    await tester.enterText(_field(2), 'Demo Water Ltd');
    await tester.tap(find.text('Save bank details'));
    await tester.pumpAndSettle();

    expect(repository.saved.single?.accountNumber, '0123456789');
    expect(find.text('GTBank · 0123456789'), findsOneWidget);
    expect(find.text('Demo Water Ltd'), findsOneWidget);
  });

  testWidgets('a short account number is rejected before saving', (
    tester,
  ) async {
    final repository = await _pumpCard(tester);
    await tester.tap(find.text('Add bank details'));
    await tester.pumpAndSettle();

    await tester.enterText(_field(0), 'GTBank');
    await tester.enterText(_field(1), '12345');
    await tester.enterText(_field(2), 'Demo Water Ltd');
    await tester.tap(find.text('Save bank details'));
    await tester.pumpAndSettle();

    expect(find.text('Enter the 10-digit account number'), findsOneWidget);
    expect(repository.saved, isEmpty);
  });

  testWidgets('saved details can be removed', (tester) async {
    final repository = await _pumpCard(
      tester,
      organization: const Organization(
        id: 'org',
        name: 'Demo Water Factory',
        bankDetails: BankDetails(
          bankName: 'GTBank',
          accountNumber: '0123456789',
          accountName: 'Demo Water Ltd',
        ),
      ),
    );
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove bank details'));
    await tester.pumpAndSettle();

    expect(repository.saved, [null]);
    expect(find.textContaining('No bank details yet'), findsOneWidget);
  });
}
