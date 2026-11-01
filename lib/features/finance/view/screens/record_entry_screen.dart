import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/action_error.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_dropdown_field.dart';
import '../../../../core/widgets/app_form_grid.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/responsive_center.dart';
import '../../../auth/data/providers/auth_providers.dart';
import '../../data/models/cash_entry.dart';
import '../../data/providers/finance_providers.dart';

/// Manually records money that doesn't come from another feature — owner
/// drawing, capital in, or anything else. Sales, debt payments, and
/// expenses are excluded from the source picker below since those land
/// here automatically when recorded in their own features.
const _manualSources = [CashSource.ownerDrawing, CashSource.other];

class RecordEntryScreen extends ConsumerStatefulWidget {
  const RecordEntryScreen({super.key});

  @override
  ConsumerState<RecordEntryScreen> createState() => _RecordEntryScreenState();
}

class _RecordEntryScreenState extends ConsumerState<RecordEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  CashDirection _direction = CashDirection.moneyOut;
  CashSource _source = CashSource.ownerDrawing;
  PaymentChannel _method = PaymentChannel.cash;

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final user = ref.read(authStateProvider);
    final amount =
        num.tryParse(_amountController.text.replaceAll(',', '')) ?? 0;
    final entry = CashEntry(
      id: 'cash-${DateTime.now().microsecondsSinceEpoch}',
      dateTime: DateTime.now(),
      direction: _direction,
      source: _source,
      amount: amount,
      method: _method,
      note: _noteController.text.trim().isEmpty
          ? null
          : _noteController.text.trim(),
      recordedBy: user?.fullName ?? 'Unknown',
    );

    await ref.read(recordCashEntryControllerProvider.notifier).record(entry);
    if (!mounted) return;

    if (ref.read(recordCashEntryControllerProvider).hasError) {
      showActionErrorSnackBar(context);
      return;
    }

    final direction = _direction == CashDirection.moneyIn ? 'in' : 'out';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Entry recorded — ${formatNaira(amount)} money $direction.',
        ),
      ),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isSaving = ref.watch(recordCashEntryControllerProvider).isLoading;

    final fields = [
      AppDropdownField<CashSource>(
        label: 'Source',
        value: _source,
        items: _manualSources,
        itemLabel: (source) => source.label,
        onChanged: (source) => setState(() => _source = source!),
      ),
      AppTextField.naira(
        label: 'Amount',
        controller: _amountController,
        validator: (value) =>
            (value == null || value.isEmpty) ? 'Enter the amount.' : null,
      ),
      AppDropdownField<PaymentChannel>(
        label: 'Method',
        value: _method,
        items: PaymentChannel.values,
        itemLabel: (method) => method.label,
        onChanged: (method) => setState(() => _method = method!),
      ),
      AppTextField(label: 'Note', controller: _noteController),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Record entry')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Form(
            key: _formKey,
            child: ListView(
              children: [
                ResponsiveCenter(
                  maxWidth: 680,
                  child: Column(
                    children: [
                      SegmentedButton<CashDirection>(
                        segments: const [
                          ButtonSegment(
                            value: CashDirection.moneyIn,
                            label: Text('Money in'),
                          ),
                          ButtonSegment(
                            value: CashDirection.moneyOut,
                            label: Text('Money out'),
                          ),
                        ],
                        selected: {_direction},
                        onSelectionChanged: (selection) =>
                            setState(() => _direction = selection.first),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppFormGrid(fields: fields),
                      const SizedBox(height: AppSpacing.xl),
                      AppButton(
                        label: 'Record entry',
                        isLoading: isSaving,
                        expanded: true,
                        onPressed: isSaving ? null : _submit,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'Sales, debt payments and expenses appear here automatically.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
