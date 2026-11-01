import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/action_error.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_form_grid.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/responsive_center.dart';
import '../../data/models/stock_item.dart';
import '../../data/providers/inventory_providers.dart';

/// Corrects an item's recorded count to match a physical recount. Always
/// requires a note explaining the discrepancy.
class AdjustCountScreen extends ConsumerStatefulWidget {
  const AdjustCountScreen({super.key, required this.item});

  final StockItem item;

  @override
  ConsumerState<AdjustCountScreen> createState() => _AdjustCountScreenState();
}

class _AdjustCountScreenState extends ConsumerState<AdjustCountScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _newCountController = TextEditingController(
    text: '${widget.item.quantityOnHand}',
  );
  final _noteController = TextEditingController();

  @override
  void dispose() {
    _newCountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final newCount = int.parse(_newCountController.text);
    await ref
        .read(stockActionControllerProvider.notifier)
        .adjustCount(
          itemId: widget.item.id,
          newCount: newCount,
          note: _noteController.text.trim(),
        );
    if (!mounted) return;

    if (ref.read(stockActionControllerProvider).hasError) {
      showActionErrorSnackBar(context);
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${widget.item.displayName} count updated to $newCount ${widget.item.unit}',
        ),
      ),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isSaving = ref.watch(stockActionControllerProvider).isLoading;

    final fields = [
      AppTextField.quantity(
        label: 'Actual count (${widget.item.unit})',
        controller: _newCountController,
        validator: (value) =>
            (value == null || value.isEmpty) ? 'Enter the actual count.' : null,
      ),
      AppTextField(
        label: 'Reason for adjustment',
        controller: _noteController,
        helperText: 'Required — explain the discrepancy',
        validator: (value) => (value == null || value.trim().isEmpty)
            ? 'Enter a reason for this adjustment.'
            : null,
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: Text('Adjust count — ${widget.item.displayName}')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: ResponsiveCenter(
            maxWidth: 680,
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Currently recorded: ${widget.item.quantityOnHand} ${widget.item.unit}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppFormGrid(fields: fields),
                  const SizedBox(height: AppSpacing.xl),
                  AppButton(
                    label: 'Save adjustment',
                    isLoading: isSaving,
                    expanded: true,
                    onPressed: isSaving ? null : _submit,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
