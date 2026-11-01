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
      'monthly_price': null,
      'payment_instructions': null,
    },
  });

  test('reads an admin_organizations row', () {
    expect(organization.staffCount, 4);
    expect(organization.lastActivityAt, isNull);
    expect(organization.subscription?.status, SubscriptionStatus.expired);
    expect(organization.subscription?.monthlyPrice, isNull);
  });

  test('search matches name and owner contact, ignoring case', () {
    expect(organization.matches(''), isTrue);
    expect(organization.matches('sunny'), isTrue);
    expect(organization.matches('ALICE@'), isTrue);
    expect(organization.matches('0803'), isTrue);
    expect(organization.matches('Kano'), isFalse);
  });

  test('plan settings round-trip to the RPC parameters', () {
    final settings = PlatformSettings.fromJson({
      'monthly_price': 15000,
      'trial_days': 14,
      'grace_days': 7,
      'payment_instructions': 'GTBank',
    });
    expect(settings.toRpcParams(), {
      'p_monthly_price': 15000,
      'p_trial_days': 14,
      'p_grace_days': 7,
      'p_payment_instructions': 'GTBank',
    });
  });
}
