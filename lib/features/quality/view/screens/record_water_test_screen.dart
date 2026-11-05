import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/action_error.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_dropdown_field.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../organizations/data/models/water_limits.dart';
import '../../../organizations/data/providers/organization_providers.dart';
import '../../../production/data/models/production_run.dart';
import '../../data/providers/quality_providers.dart';

/// Records today's water test for a shift. The readings are checked
/// against the organization's limits; a failure alerts the owner.
class RecordWaterTestScreen extends ConsumerStatefulWidget {
  const RecordWaterTestScreen({super.key});

  /// Before this hour the morning shift is suggested.
  static const afternoonStartsHour = 14;

  @override
  ConsumerState<RecordWaterTestScreen> createState() =>
      _RecordWaterTestScreenState();
}

class _RecordWaterTestScreenState extends ConsumerState<RecordWaterTestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _ph = TextEditingController();
  final _tds = TextEditingController();
  final _chlorine = TextEditingController();
  final _note = TextEditingController();
  late ProductionShift _shift =
      DateTime.now().hour < RecordWaterTestScreen.afternoonStartsHour
      ? ProductionShift.morning
      : ProductionShift.afternoon;

  @override
  void dispose() {
    for (final controller in [_ph, _tds, _chlorine, _note]) {
      controller.dispose();
    }
    super.dispose();
  }

  static String? _reading(String? value) =>
      num.tryParse(value ?? '') == null ? 'Enter the reading' : null;

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final note = _note.text.trim();
    final saved = await ref
        .read(qualityActionControllerProvider.notifier)
        .recordWaterTest(
          date: DateTime.now(),
          shift: _shift,
          ph: num.parse(_ph.text),
          tds: num.parse(_tds.text),
          chlorine: num.parse(_chlorine.text),
          note: note.isEmpty ? null : note,
        );
    if (!mounted) return;
    if (!saved) {
      showActionErrorSnackBar(
        context,
        message: readableErrorMessage(
          ref.read(qualityActionControllerProvider).error,
        ),
      );
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final busy = ref.watch(qualityActionControllerProvider).isLoading;
    final limits =
        ref.watch(currentOrganizationProvider)?.waterLimits ??
        const WaterLimits();
    String plain(num value) => WaterLimits.plain(value);

    return Scaffold(
      appBar: AppBar(title: const Text('Record water test')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            AppDropdownField<ProductionShift>(
              label: 'Shift (today)',
              value: _shift,
              items: ProductionShift.values,
              itemLabel: (shift) => shift.label,
              onChanged: (shift) => setState(() => _shift = shift!),
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField.decimal(
              hint: 'e.g. 7.2',
              label: 'pH',
              controller: _ph,
              helperText:
                  'Allowed ${plain(limits.phMin)}–${plain(limits.phMax)}',
              validator: _reading,
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField.decimal(
              hint: 'e.g. 120',
              label: 'TDS',
              controller: _tds,
              unit: 'mg/L',
              helperText: 'Up to ${plain(limits.tdsMax)} mg/L',
              validator: _reading,
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField.decimal(
              hint: 'e.g. 0.3',
              label: 'Residual chlorine',
              controller: _chlorine,
              unit: 'mg/L',
              helperText:
                  'Allowed ${plain(limits.chlorineMin)}–'
                  '${plain(limits.chlorineMax)} mg/L',
              validator: _reading,
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              hint: 'e.g. Tested after backwash',
              label: 'Note (optional)',
              controller: _note,
            ),
            const SizedBox(height: AppSpacing.lg),
            AppButton(
              label: 'Save water test',
              isLoading: busy,
              onPressed: busy ? null : _save,
            ),
          ],
        ),
      ),
    );
  }
}
