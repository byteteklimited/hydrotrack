import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_dropdown_field.dart';
import '../../../../core/widgets/app_form_dialog.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../subscriptions/data/models/plan.dart';
import '../../data/models/admin_organization.dart';
import '../../data/providers/admin_providers.dart';

/// Limits the server also enforces (migration 0023).
const _maxMonths = 24;
const _maxFreeDays = 365;

Future<void> showRecordPaymentDialog(
  BuildContext context,
  AdminOrganization organization,
  List<Plan> plans,
) => showDialog<void>(
  context: context,
  builder: (_) =>
      _RecordPaymentDialog(organization: organization, plans: plans),
);

Future<void> showChangePlanDialog(
  BuildContext context,
  AdminOrganization organization,
  List<Plan> plans,
) => showDialog<void>(
  context: context,
  builder: (_) => _ChangePlanDialog(organization: organization, plans: plans),
);

/// The plan the owner chose, else the one they're on.
Plan _startingPlan(AdminOrganization organization, List<Plan> plans) {
  final subscription = organization.subscription;
  final key = subscription?.requestedPlanKey ?? subscription?.plan?.key;
  return plans.firstWhere((plan) => plan.key == key, orElse: () => plans.first);
}

AppDropdownField<Plan> _planField({
  required String label,
  required Plan value,
  required List<Plan> plans,
  required ValueChanged<Plan> onChanged,
}) => AppDropdownField<Plan>(
  label: label,
  value: value,
  items: plans,
  itemLabel: (plan) => '${plan.name} · ${formatNaira(plan.monthlyPrice)}',
  onChanged: (plan) {
    if (plan != null) onChanged(plan);
  },
);

Future<void> showFreeDaysDialog(
  BuildContext context,
  AdminOrganization organization,
) => showDialog<void>(
  context: context,
  builder: (_) => _FreeDaysDialog(organization: organization),
);

Future<void> showSuspendDialog(
  BuildContext context,
  AdminOrganization organization,
) => showDialog<void>(
  context: context,
  builder: (_) => _SuspendDialog(organization: organization),
);

String? _wholeNumberBetween(String? value, int min, int max, String what) {
  final number = int.tryParse(value ?? '');
  return number != null && number >= min && number <= max
      ? null
      : 'Enter $what from $min to $max';
}

String? _optional(TextEditingController controller) =>
    controller.text.trim().isEmpty ? null : controller.text.trim();

class _RecordPaymentDialog extends ConsumerStatefulWidget {
  const _RecordPaymentDialog({required this.organization, required this.plans});

  final AdminOrganization organization;
  final List<Plan> plans;

  @override
  ConsumerState<_RecordPaymentDialog> createState() =>
      _RecordPaymentDialogState();
}

class _RecordPaymentDialogState extends ConsumerState<_RecordPaymentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _months = TextEditingController(text: '1');
  final _amount = TextEditingController();
  final _note = TextEditingController();
  late Plan _plan = _startingPlan(widget.organization, widget.plans);

  @override
  void initState() {
    super.initState();
    _fillAmount();
    _months.addListener(_fillAmount);
  }

  /// Suggests the plan's price × months; the admin can change it.
  void _fillAmount() {
    final months = int.tryParse(_months.text);
    if (months == null) return;
    _amount.text = NumberFormat.decimalPattern(
      'en_NG',
    ).format(_plan.monthlyPrice * months);
  }

  @override
  void dispose() {
    _months.dispose();
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppFormDialog(
      busy: ref.watch(adminActionControllerProvider).isLoading,
      error: () => ref.read(adminActionControllerProvider).error,
      formKey: _formKey,
      title: 'Record payment',
      intro:
          'For ${widget.organization.name}. It moves to the plan paid for, '
          'and the months are added after its trial or current paid time '
          '(or from today if that has run out).',
      submitLabel: 'Record payment',
      onSubmit: () => ref
          .read(adminActionControllerProvider.notifier)
          .recordPayment(
            organizationId: widget.organization.id,
            planKey: _plan.key,
            amount: parseNairaText(_amount.text),
            months: int.parse(_months.text),
            note: _optional(_note),
          ),
      fields: [
        _planField(
          label: 'Plan paid for',
          value: _plan,
          plans: widget.plans,
          onChanged: (plan) {
            setState(() => _plan = plan);
            _fillAmount();
          },
        ),
        AppTextField.quantity(
          hint: 'e.g. 1',
          label: 'Months paid for',
          controller: _months,
          unit: 'months',
          validator: (v) => _wholeNumberBetween(v, 1, _maxMonths, 'months'),
        ),
        AppTextField.naira(
          hint: 'e.g. 15,000',
          label: 'Amount received',
          controller: _amount,
          validator: (v) =>
              (v ?? '').trim().isEmpty ? 'Enter the amount' : null,
        ),
        AppTextField(
          hint: 'e.g. GTBank transfer, ref 12345',
          label: 'Note (optional)',
          controller: _note,
        ),
      ],
    );
  }
}

class _ChangePlanDialog extends ConsumerStatefulWidget {
  const _ChangePlanDialog({required this.organization, required this.plans});

  final AdminOrganization organization;
  final List<Plan> plans;

  @override
  ConsumerState<_ChangePlanDialog> createState() => _ChangePlanDialogState();
}

class _ChangePlanDialogState extends ConsumerState<_ChangePlanDialog> {
  final _formKey = GlobalKey<FormState>();
  final _note = TextEditingController();
  late Plan _plan = _startingPlan(widget.organization, widget.plans);

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppFormDialog(
      busy: ref.watch(adminActionControllerProvider).isLoading,
      error: () => ref.read(adminActionControllerProvider).error,
      formKey: _formKey,
      title: 'Change plan',
      intro:
          'For ${widget.organization.name}, without a payment (to move '
          'with a payment, use Record payment). Its paid time stays the '
          'same. On a smaller plan nothing is switched off; it just can\'t '
          'add staff or locations beyond the new limits.',
      submitLabel: 'Change plan',
      onSubmit: () => ref
          .read(adminActionControllerProvider.notifier)
          .setPlan(
            organizationId: widget.organization.id,
            planKey: _plan.key,
            note: _optional(_note),
          ),
      fields: [
        _planField(
          label: 'New plan',
          value: _plan,
          plans: widget.plans,
          onChanged: (plan) => setState(() => _plan = plan),
        ),
        AppTextField(
          hint: 'e.g. Asked to move down',
          label: 'Note (optional)',
          controller: _note,
        ),
      ],
    );
  }
}

class _FreeDaysDialog extends ConsumerStatefulWidget {
  const _FreeDaysDialog({required this.organization});

  final AdminOrganization organization;

  @override
  ConsumerState<_FreeDaysDialog> createState() => _FreeDaysDialogState();
}

class _FreeDaysDialogState extends ConsumerState<_FreeDaysDialog> {
  final _formKey = GlobalKey<FormState>();
  final _days = TextEditingController();
  final _note = TextEditingController();

  @override
  void dispose() {
    _days.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppFormDialog(
      busy: ref.watch(adminActionControllerProvider).isLoading,
      error: () => ref.read(adminActionControllerProvider).error,
      formKey: _formKey,
      title: 'Give free days',
      intro:
          'For ${widget.organization.name}. Added to its trial while it is '
          'on one, otherwise to its paid time.',
      submitLabel: 'Give free days',
      onSubmit: () => ref
          .read(adminActionControllerProvider.notifier)
          .addFreeDays(
            organizationId: widget.organization.id,
            days: int.parse(_days.text),
            note: _optional(_note),
          ),
      fields: [
        AppTextField.quantity(
          hint: 'e.g. 7',
          label: 'Free days',
          controller: _days,
          unit: 'days',
          validator: (v) => _wholeNumberBetween(v, 1, _maxFreeDays, 'days'),
        ),
        AppTextField(
          hint: 'e.g. Goodwill for the outage',
          label: 'Note (optional)',
          controller: _note,
        ),
      ],
    );
  }
}

class _SuspendDialog extends ConsumerStatefulWidget {
  const _SuspendDialog({required this.organization});

  final AdminOrganization organization;

  @override
  ConsumerState<_SuspendDialog> createState() => _SuspendDialogState();
}

class _SuspendDialogState extends ConsumerState<_SuspendDialog> {
  final _formKey = GlobalKey<FormState>();
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppFormDialog(
      busy: ref.watch(adminActionControllerProvider).isLoading,
      error: () => ref.read(adminActionControllerProvider).error,
      formKey: _formKey,
      title: 'Suspend ${widget.organization.name}?',
      intro:
          'It becomes read-only straight away: everyone can still sign in and '
          'view records, but nothing new can be recorded until you resume it. '
          'Its staff see the reason.',
      submitLabel: 'Suspend',
      destructive: true,
      onSubmit: () => ref
          .read(adminActionControllerProvider.notifier)
          .setSuspended(
            organizationId: widget.organization.id,
            suspended: true,
            reason: _reason.text.trim(),
          ),
      fields: [
        AppTextField(
          hint: 'e.g. Payment reversed by the bank',
          label: 'Reason',
          controller: _reason,
          validator: (v) =>
              (v ?? '').trim().isEmpty ? 'Give a reason for suspending' : null,
        ),
      ],
    );
  }
}
