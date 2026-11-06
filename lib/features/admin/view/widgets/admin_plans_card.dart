import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/action_error.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_form_dialog.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../subscriptions/data/models/plan.dart';
import '../../../subscriptions/data/providers/subscription_providers.dart';
import '../../data/providers/admin_providers.dart';

/// The three plans with their prices and limits; each can be edited.
class AdminPlansCard extends ConsumerWidget {
  const AdminPlansCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plansAsync = ref.watch(plansProvider);
    return AppCard(
      title: 'Plans',
      child: plansAsync.when(
        loading: () => const AppLoading(),
        error: (error, stackTrace) => Text(
          readableErrorMessage(error) ??
              "Couldn't load the plans. Check your connection and try again.",
        ),
        data: (plans) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final plan in plans)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  '${plan.name} · ${formatNaira(plan.monthlyPrice)} a month',
                ),
                subtitle: Text(
                  '${plan.staffLimit} · ${plan.locationLimit}',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: 'Edit ${plan.name}',
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => _EditPlanDialog(plan: plan),
                  ),
                ),
              ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Changes apply to every organization on the plan straight away. '
              'Nothing is switched off if a limit goes down.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditPlanDialog extends ConsumerStatefulWidget {
  const _EditPlanDialog({required this.plan});

  final Plan plan;

  @override
  ConsumerState<_EditPlanDialog> createState() => _EditPlanDialogState();
}

class _EditPlanDialogState extends ConsumerState<_EditPlanDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _price = TextEditingController(
    text: NumberFormat.decimalPattern('en_NG').format(widget.plan.monthlyPrice),
  );
  late final _maxStaff = TextEditingController(
    text: widget.plan.maxStaff?.toString() ?? '',
  );
  late final _maxLocations = TextEditingController(
    text: widget.plan.maxLocations?.toString() ?? '',
  );

  @override
  void dispose() {
    _price.dispose();
    _maxStaff.dispose();
    _maxLocations.dispose();
    super.dispose();
  }

  /// Empty means unlimited; otherwise at least 1.
  static String? _limit(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return null;
    final number = int.tryParse(text);
    return number != null && number >= 1
        ? null
        : 'Enter 1 or more, or leave empty for unlimited';
  }

  static int? _limitValue(TextEditingController controller) =>
      int.tryParse(controller.text.trim());

  @override
  Widget build(BuildContext context) {
    return AppFormDialog(
      busy: ref.watch(adminActionControllerProvider).isLoading,
      error: () => ref.read(adminActionControllerProvider).error,
      formKey: _formKey,
      title: 'Edit ${widget.plan.name}',
      intro: widget.plan.description,
      submitLabel: 'Save plan',
      onSubmit: () => ref
          .read(adminActionControllerProvider.notifier)
          .updatePlan(
            planKey: widget.plan.key,
            monthlyPrice: parseNairaText(_price.text),
            maxStaff: _limitValue(_maxStaff),
            maxLocations: _limitValue(_maxLocations),
          ),
      fields: [
        AppTextField.naira(
          hint: 'e.g. 25,000',
          label: 'Monthly price',
          controller: _price,
          validator: (v) =>
              (v ?? '').trim().isEmpty ? 'Enter the monthly price' : null,
        ),
        AppTextField.quantity(
          hint: 'Empty for unlimited',
          label: 'Staff users (owners not counted)',
          controller: _maxStaff,
          validator: _limit,
        ),
        AppTextField.quantity(
          hint: 'Empty for unlimited',
          label: 'Factories and depots',
          controller: _maxLocations,
          validator: _limit,
        ),
      ],
    );
  }
}
