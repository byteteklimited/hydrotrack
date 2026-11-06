import 'package:flutter_test/flutter_test.dart';
import 'package:hydrotrack/features/admin/data/models/admin_organization.dart';
import 'package:hydrotrack/features/admin/data/models/platform_settings.dart';
import 'package:hydrotrack/features/subscriptions/data/models/subscription.dart';

void main() {
  final organization = AdminOrganization.fromJson({
    'id': 'org-1',
    'name': 'Sunny Water',
    'created_at': '2026-11-01T08:00:00Z',
    'business_phone': '08031234567',
    'owner_name': 'Alice Owner',
    'owner_phone': null,
    'owner_email': 'alice@example.com',
    'staff_count': 4,
    'last_activity_at': null,
    'subscription': {
      'status': 'expired',
      'trial_ends_at': '2026-10-01T08:00:00Z',
      'paid_until': null,
      'ends_at': '2026-10-01T08:00:00Z',
      'access_ends_at': '2026-10-08T08:00:00Z',
      'suspended_at': null,
      'suspended_reason': null,
      'plan': {
        'key': 'starter',
        'name': 'Starter',
        'description': 'For small factories',
        'monthly_price': 15000,
        'max_staff': 3,
        'max_locations': 1,
        'is_popular': false,
      },
      'requested_plan_key': 'premium',
      'staff_in_use': 4,
      'locations_in_use': 1,
      'bank_name': null,
      'account_number': null,
      'account_name': null,
      'payment_instructions': null,
    },
  });

  test('reads an admin_organizations row', () {
    expect(organization.staffCount, 4);
    expect(organization.lastActivityAt, isNull);
    expect(organization.subscription?.status, SubscriptionStatus.expired);
    expect(organization.subscription?.plan?.name, 'Starter');
    expect(organization.subscription?.requestedPlanKey, 'premium');
    expect(organization.subscription?.bankAccount, isNull);
  });

  test('search matches name and owner contact, ignoring case', () {
    expect(organization.matches(''), isTrue);
    expect(organization.matches('sunny'), isTrue);
    expect(organization.matches('ALICE@'), isTrue);
    expect(organization.matches('0803'), isTrue);
    expect(organization.matches('Kano'), isFalse);
  });

  test('settings round-trip to the RPC parameters', () {
    final settings = PlatformSettings.fromJson({
      'trial_days': 14,
      'grace_days': 7,
      'bank_name': 'Moniepoint MFB',
      'account_number': '8137131177',
      'account_name': 'Byte Tek Limited',
      'payment_instructions': 'Send the receipt on WhatsApp',
    });
    expect(settings.toRpcParams(), {
      'p_trial_days': 14,
      'p_grace_days': 7,
      'p_bank_name': 'Moniepoint MFB',
      'p_account_number': '8137131177',
      'p_account_name': 'Byte Tek Limited',
      'p_payment_instructions': 'Send the receipt on WhatsApp',
    });
  });

  test('no bank account until all three details are set', () {
    final settings = PlatformSettings.fromJson({
      'trial_days': 14,
      'grace_days': 7,
      'bank_name': 'Moniepoint MFB',
      'account_number': null,
      'account_name': null,
    });
    expect(settings.bankAccount, isNull);
    expect(settings.toRpcParams()['p_bank_name'], isNull);
  });
}
