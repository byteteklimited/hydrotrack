import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hydrotrack/features/organizations/data/models/business_profile.dart';
import 'package:hydrotrack/features/organizations/data/models/organization.dart';
import 'package:hydrotrack/features/organizations/data/models/setup_checklist.dart';
import 'package:hydrotrack/features/organizations/data/providers/organization_providers.dart';
import 'package:hydrotrack/features/organizations/data/repositories/organization_repository.dart';
import 'package:hydrotrack/features/organizations/view/widgets/setup_checklist_card.dart';

class _FakeOrganizations implements OrganizationRepository {
  final dismissed = <String>[];

  @override
  Set<String> dismissedSetupChecklists() => dismissed.toSet();

  @override
  Future<void> dismissSetupChecklist(String organizationId) async =>
      dismissed.add(organizationId);

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

const _newOrganization = Organization(id: 'org', name: 'Sunny Water');
const _complete = Organization(
  id: 'org',
  name: 'Sunny Water',
  logoPath: 'org/logo.png',
  profile: BusinessProfile(
    address: 'Kano',
    phone: '08031234567',
    nafdacNumber: 'A1-2345',
  ),
);

Future<_FakeOrganizations> _pump(
  WidgetTester tester,
  Organization organization,
) async {
  final repository = _FakeOrganizations();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        organizationRepositoryProvider.overrideWithValue(repository),
        currentOrganizationProvider.overrideWith((ref) => organization),
      ],
      child: const MaterialApp(home: Scaffold(body: SetupChecklistCard())),
    ),
  );
  return repository;
}

void main() {
  test('the profile step lists exactly what is missing', () {
    final step = SetupChecklist.forOrganization(_newOrganization).steps.single;
    expect(step.missing, [
      'address',
      'phone number',
      'logo',
      'CAC/RC or NAFDAC number',
    ]);
    expect(SetupChecklist.forOrganization(_complete).isComplete, isTrue);
  });

  testWidgets('shows what is left for a new organization', (tester) async {
    await _pump(tester, _newOrganization);
    expect(find.text('Finish setting up · 0 of 1 done'), findsOneWidget);
    expect(find.textContaining('Still to add: address'), findsOneWidget);
  });

  testWidgets('hidden once the profile is complete', (tester) async {
    await _pump(tester, _complete);
    expect(find.textContaining('Finish setting up'), findsNothing);
  });

  testWidgets('dismissing hides it and remembers that', (tester) async {
    final repository = await _pump(tester, _newOrganization);
    await tester.tap(find.text('Dismiss'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Finish setting up'), findsNothing);
    expect(repository.dismissed, ['org']);
  });
}
