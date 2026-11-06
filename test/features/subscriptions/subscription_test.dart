import 'package:flutter_test/flutter_test.dart';
import 'package:hydrotrack/features/subscriptions/data/models/plan.dart';
import 'package:hydrotrack/features/subscriptions/data/models/subscription.dart';
import 'package:hydrotrack/features/subscriptions/data/models/subscription_event.dart';
import 'package:hydrotrack/features/subscriptions/view/widgets/subscription_banner.dart';
import 'package:hydrotrack/features/subscriptions/view/widgets/plan_usage.dart';
import 'package:hydrotrack/features/subscriptions/view/widgets/subscription_history_list.dart';
import 'package:hydrotrack/features/subscriptions/view/widgets/subscription_status_tag.dart';

final _now = DateTime.utc(2026, 11, 10, 12);

Subscription _subscription(
  String status, {
  DateTime? endsAt,
  DateTime? accessEndsAt,
  DateTime? suspendedAt,
}) {
  final ends = endsAt ?? _now.add(const Duration(days: 2));
  return Subscription.fromJson({
    'status': status,
    'trial_ends_at': ends.toIso8601String(),
    'paid_until': null,
    'ends_at': ends.toIso8601String(),
    'access_ends_at': (accessEndsAt ?? ends.add(const Duration(days: 7)))
        .toIso8601String(),
    'suspended_at': suspendedAt?.toIso8601String(),
    'suspended_reason': suspendedAt == null ? null : 'Cheque bounced',
    'plan': _standard,
    'requested_plan_key': null,
    'staff_in_use': 10,
    'locations_in_use': 2,
    'bank_name': 'Moniepoint MFB',
    'account_number': '8137131177',
    'account_name': 'Byte Tek Limited',
    'payment_instructions': 'Send the receipt on WhatsApp',
  });
}

const _standard = {
  'key': 'standard',
  'name': 'Standard',
  'description': 'For growing factories',
  'monthly_price': 25000,
  'max_staff': 10,
  'max_locations': 1,
  'is_popular': true,
};

void main() {
  group('Subscription', () {
    test('reads the server summary', () {
      final subscription = _subscription('grace');
      expect(subscription.status, SubscriptionStatus.grace);
      expect(subscription.plan?.monthlyPrice, 25000);
      expect(subscription.bankAccount?.accountNumber, '8137131177');
      expect(subscription.paymentInstructions, 'Send the receipt on WhatsApp');
      expect(subscription.canRecord, isTrue);
    });

    test('expired and suspended are read-only', () {
      expect(_subscription('expired').canRecord, isFalse);
      expect(_subscription('suspended', suspendedAt: _now).canRecord, isFalse);
    });

    test('a device decides by the time access ends', () {
      final subscription = _subscription(
        'trial',
        accessEndsAt: _now.add(const Duration(hours: 1)),
      );
      expect(subscription.canRecordAt(_now), isTrue);
      expect(
        subscription.canRecordAt(_now.add(const Duration(hours: 2))),
        isFalse,
      );
      expect(
        _subscription('suspended', suspendedAt: _now).canRecordAt(_now),
        isFalse,
      );
    });

    test('days left round up and never go negative', () {
      expect(
        Subscription.daysUntil(_now.add(const Duration(hours: 30)), _now),
        2,
      );
      expect(
        Subscription.daysUntil(_now.subtract(const Duration(days: 1)), _now),
        0,
      );
    });
  });

  group('plans', () {
    test('limits read as owners see them', () {
      final standard = Plan.fromJson(_standard);
      expect(standard.staffLimit, 'Up to 10 staff users');
      expect(standard.locationLimit, 'One factory');
      final premium = Plan.fromJson({
        ..._standard,
        'key': 'premium',
        'max_staff': null,
        'max_locations': null,
      });
      expect(premium.staffLimit, 'Unlimited staff users');
      expect(premium.locationLimit, 'Multiple factories and depots');
    });

    test('usage says when the plan is full or over', () {
      final lines = planUsageLines(_subscription('active'));
      expect(
        lines[0].text,
        'Staff users: 10 of 10 (owners not counted) · full',
      );
      expect(lines[0].over, isFalse);
      expect(lines[1].text, 'Factories and depots: 2 of 1');
      expect(lines[1].over, isTrue);
    });

    test('a status saved before plans existed still reads', () {
      final old = Subscription.fromJson({
        'status': 'trial',
        'trial_ends_at': _now.toIso8601String(),
        'paid_until': null,
        'ends_at': _now.toIso8601String(),
        'access_ends_at': _now.toIso8601String(),
        'monthly_price': null,
      });
      expect(old.plan, isNull);
      expect(planUsageLines(old), isEmpty);
    });

    test('payments name the plan paid for', () {
      expect(
        SubscriptionHistoryList.describe(
          SubscriptionEvent.fromJson({
            'id': 'e1',
            'created_at': _now.toIso8601String(),
            'kind': 'plan_changed',
            'plan_key': 'premium',
          }),
        ),
        'Plan changed to Premium',
      );
    });
  });

  group('summary line', () {
    test('trial says when it ends and how long is left', () {
      expect(
        subscriptionSummary(_subscription('trial'), _now),
        'Free trial ends 12 Nov 2026 (2 days left)',
      );
    });

    test('suspended gives the reason', () {
      expect(
        subscriptionSummary(
          _subscription('suspended', suspendedAt: _now),
          _now,
        ),
        'Suspended: Cheque bounced',
      );
    });
  });

  group('banner', () {
    String? message(Subscription subscription, {required bool canManage}) =>
        SubscriptionBanner.message(
          subscription: subscription,
          canManage: canManage,
          now: _now,
        );

    test('read-only shows for everyone; only managers are told to renew', () {
      final expired = _subscription('expired');
      expect(message(expired, canManage: true), contains('Tap to renew'));
      expect(
        message(expired, canManage: false),
        contains('Ask the owner to renew'),
      );
    });

    test('payment due shows only to owners and admins', () {
      final grace = _subscription('grace');
      expect(message(grace, canManage: true), startsWith('Payment due'));
      expect(message(grace, canManage: false), isNull);
    });

    test('the trial is mentioned only in its last days', () {
      expect(message(_subscription('trial'), canManage: true), isNotNull);
      expect(
        message(
          _subscription('trial', endsAt: _now.add(const Duration(days: 10))),
          canManage: true,
        ),
        isNull,
      );
      expect(message(_subscription('active'), canManage: true), isNull);
    });
  });

  test('history lines describe each event', () {
    SubscriptionEvent event(Map<String, dynamic> json) =>
        SubscriptionEvent.fromJson({
          'id': 'e1',
          'created_at': _now.toIso8601String(),
          ...json,
        });
    expect(
      SubscriptionHistoryList.describe(
        event({
          'kind': 'payment',
          'amount': 30000,
          'months': 2,
          'ends_at': '2027-01-12T12:00:00Z',
        }),
      ),
      '₦30,000 for 2 months · until 12 Jan 2027',
    );
    expect(
      SubscriptionHistoryList.describe(
        event({
          'kind': 'payment',
          'plan_key': 'standard',
          'amount': 25000,
          'months': 1,
          'ends_at': '2027-01-12T12:00:00Z',
        }),
      ),
      'Standard · ₦25,000 for 1 month · until 12 Jan 2027',
    );
    expect(
      SubscriptionHistoryList.describe(event({'kind': 'free_days', 'days': 1})),
      '1 free day',
    );
  });
}
