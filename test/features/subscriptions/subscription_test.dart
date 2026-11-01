import 'package:flutter_test/flutter_test.dart';
import 'package:hydrotrack/features/subscriptions/data/models/subscription.dart';
import 'package:hydrotrack/features/subscriptions/data/models/subscription_event.dart';
import 'package:hydrotrack/features/subscriptions/view/widgets/subscription_banner.dart';
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
    'monthly_price': 15000,
    'payment_instructions': 'GTBank 0123456789',
  });
}

void main() {
  group('Subscription', () {
    test('reads the server summary', () {
      final subscription = _subscription('grace');
      expect(subscription.status, SubscriptionStatus.grace);
      expect(subscription.monthlyPrice, 15000);
      expect(subscription.paymentInstructions, 'GTBank 0123456789');
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
        'Suspended by HydroTrack: Cheque bounced',
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
      SubscriptionHistoryList.describe(event({'kind': 'free_days', 'days': 1})),
      '1 free day',
    );
  });
}
