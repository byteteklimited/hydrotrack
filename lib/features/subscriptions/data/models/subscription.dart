import 'bank_account.dart';
import 'plan.dart';

/// Shown when a device working offline is asked to record after the
/// organization's access ended (the server would refuse it anyway).
const subscriptionEndedOnDeviceMessage =
    "This organization's subscription has ended, so nothing new can be "
    'recorded. You can still view records. If the owner has just renewed, '
    'connect to the internet so this device can update, then try again.';

/// Where an organization's subscription stands (migration 0023).
enum SubscriptionStatus {
  trial('Free trial'),
  active('Active'),
  grace('Payment due'),
  expired('Ended'),
  suspended('Suspended');

  const SubscriptionStatus(this.label);

  final String label;

  static SubscriptionStatus fromKey(String key) =>
      values.firstWhere((status) => status.name == key);
}

/// An organization's subscription: its plan, a free trial, then a grace
/// period before it becomes read-only.
class Subscription {
  const Subscription({
    required this.status,
    required this.trialEndsAt,
    required this.endsAt,
    required this.accessEndsAt,
    this.paidUntil,
    this.suspendedAt,
    this.suspendedReason,
    this.plan,
    this.requestedPlanKey,
    this.staffInUse = 0,
    this.locationsInUse = 0,
    this.bankAccount,
    this.paymentInstructions,
  });

  final SubscriptionStatus status;
  final DateTime trialEndsAt;
  final DateTime? paidUntil;

  /// When the trial or paid time ends.
  final DateTime endsAt;

  /// When it becomes read-only (end + grace).
  final DateTime accessEndsAt;
  final DateTime? suspendedAt;
  final String? suspendedReason;

  /// The plan it's on (Standard during the trial). Null only in a status
  /// saved on a device before plans existed.
  final Plan? plan;

  /// The plan the owner chose, waiting for HydroTrack to record payment.
  final String? requestedPlanKey;

  /// Staff who aren't owners, plus open invites.
  final int staffInUse;

  /// Active factories and depots.
  final int locationsInUse;

  /// Where to pay; null until HydroTrack sets it.
  final BankAccount? bankAccount;

  /// Anything else about paying, e.g. where to send the receipt.
  final String? paymentInstructions;

  /// Whether new records can be made — as the server saw it.
  bool get canRecord =>
      status != SubscriptionStatus.expired &&
      status != SubscriptionStatus.suspended;

  /// Whether new records can be made at [now] (used on a device working
  /// offline, where the status may be hours old).
  bool canRecordAt(DateTime now) =>
      suspendedAt == null && now.isBefore(accessEndsAt);

  /// Whole days from [now] until [until], never negative.
  static int daysUntil(DateTime until, DateTime now) {
    final days = until.difference(now).inHours / Duration.hoursPerDay;
    return days <= 0 ? 0 : days.ceil();
  }

  factory Subscription.fromJson(Map<String, dynamic> json) => Subscription(
    status: SubscriptionStatus.fromKey(json['status'] as String),
    trialEndsAt: DateTime.parse(json['trial_ends_at'] as String),
    paidUntil: _date(json['paid_until']),
    endsAt: DateTime.parse(json['ends_at'] as String),
    accessEndsAt: DateTime.parse(json['access_ends_at'] as String),
    suspendedAt: _date(json['suspended_at']),
    suspendedReason: json['suspended_reason'] as String?,
    plan: json['plan'] == null
        ? null
        : Plan.fromJson(Map<String, dynamic>.from(json['plan'] as Map)),
    requestedPlanKey: json['requested_plan_key'] as String?,
    staffInUse: json['staff_in_use'] as int? ?? 0,
    locationsInUse: json['locations_in_use'] as int? ?? 0,
    bankAccount: BankAccount.fromJson(json),
    paymentInstructions: json['payment_instructions'] as String?,
  );

  static DateTime? _date(Object? value) =>
      value == null ? null : DateTime.parse(value as String);
}
