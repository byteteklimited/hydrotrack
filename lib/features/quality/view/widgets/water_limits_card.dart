import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/action_error.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../organizations/data/models/water_limits.dart';
import '../../../organizations/data/providers/organization_providers.dart';

/// Edits the organization's water test limits (defaults: NIS 554).
class WaterLimitsCard extends ConsumerStatefulWidget {
  const WaterLimitsCard({super.key});

  @override
  ConsumerState<WaterLimitsCard> createState() => _WaterLimitsCardState();
}

class _WaterLimitsCardState extends ConsumerState<WaterLimitsCard> {
  final _formKey = GlobalKey<FormState>();
  late final WaterLimits _initial =
      ref.read(currentOrganizationProvider)?.waterLimits ?? const WaterLimits();
  late final _phMin = _field(_initial.phMin);
  late final _phMax = _field(_initial.phMax);
  late final _tdsMax = _field(_initial.tdsMax);
  late final _chlorineMin = _field(_initial.chlorineMin);
  late final _chlorineMax = _field(_initial.chlorineMax);

  static TextEditingController _field(num value) =>
      TextEditingController(text: WaterLimits.plain(value));

  @override
  void dispose() {
    for (final field in [_phMin, _phMax, _tdsMax, _chlorineMin, _chlorineMax]) {
      field.dispose();
    }
    super.dispose();
  }

  static String? _number(String? value) =>
      num.tryParse(value ?? '') == null ? 'Enter a number' : null;

  String? _below(TextEditingController min, TextEditingController max) {
    final low = num.tryParse(min.text);
    final high = num.tryParse(max.text);
    if (low == null || high == null) return 'Enter a number';
    return low < high ? null : 'Must be above the minimum';
  }

  Future<void> _save() async {
    final organization = ref.read(currentOrganizationProvider);
    if (organization == null || !(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    final saved = await ref
        .read(organizationActionControllerProvider.notifier)
        .saveWaterLimits(
          organizationId: organization.id,
          limits: WaterLimits(
            phMin: num.parse(_phMin.text),
            phMax: num.parse(_phMax.text),
            tdsMax: num.parse(_tdsMax.text),
            chlorineMin: num.parse(_chlorineMin.text),
            chlorineMax: num.parse(_chlorineMax.text),
          ),
        );
    if (!mounted) return;
    if (saved == null) {
      showActionErrorSnackBar(
        context,
        message: readableErrorMessage(
          ref.read(organizationActionControllerProvider).error,
        ),
      );
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Water limits saved')));
  }

  Widget _pair(String label, Widget left, Widget right) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.md),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: AppSpacing.xs),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: left),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: right),
          ],
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final busy = ref.watch(organizationActionControllerProvider).isLoading;
    return AppCard(
      title: 'Water test limits',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'A test outside these fails and alerts the owner. Defaults are '
              'the Nigerian standard NIS 554.',
            ),
            const SizedBox(height: AppSpacing.md),
            _pair(
              'pH',
              AppTextField.decimal(
                label: 'Minimum',
                controller: _phMin,
                validator: _number,
              ),
              AppTextField.decimal(
                label: 'Maximum',
                controller: _phMax,
                validator: (_) => _below(_phMin, _phMax),
              ),
            ),
            AppTextField.decimal(
              label: 'TDS maximum',
              controller: _tdsMax,
              unit: 'mg/L',
              validator: _number,
            ),
            const SizedBox(height: AppSpacing.md),
            _pair(
              'Residual chlorine (mg/L)',
              AppTextField.decimal(
                label: 'Minimum',
                controller: _chlorineMin,
                validator: _number,
              ),
              AppTextField.decimal(
                label: 'Maximum',
                controller: _chlorineMax,
                validator: (_) => _below(_chlorineMin, _chlorineMax),
              ),
            ),
            AppButton(
              label: 'Save limits',
              isLoading: busy,
              onPressed: busy ? null : _save,
            ),
          ],
        ),
      ),
    );
  }
}
