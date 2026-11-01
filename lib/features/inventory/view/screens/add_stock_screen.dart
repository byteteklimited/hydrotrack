import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/action_error.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_form_grid.dart';
import '../../../../core/widgets/app_optional_date_field.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/responsive_center.dart';
import '../../data/models/stock_item.dart';
import '../../data/providers/inventory_providers.dart';

/// Records a delivery — stock received and added to an item's balance.
class AddStockScreen extends ConsumerStatefulWidget {
  const AddStockScreen({super.key, required this.item});

  final StockItem item;

  @override
  ConsumerState<AddStockScreen> createState() => _AddStockScreenState();
}

class _AddStockScreenState extends ConsumerState<AddStockScreen> {
  final _formKey = GlobalKey<FormState>();
  final _quantityController = TextEditingController();
  final _noteController = TextEditingController();
  DateTime? _expiryDate;

  @override
  void dispose() {
    _quantityController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final quantity = int.parse(_quantityController.text);
    await ref
        .read(stockActionControllerProvider.notifier)
        .addStock(
          itemId: widget.item.id,
          quantity: quantity,
          note: _noteController.text.trim().isEmpty
              ? null
              : _noteController.text.trim(),
          expiryDate: _expiryDate,
        );
    if (!mounted) return;

    if (ref.read(stockActionControllerProvider).hasError) {
      showActionErrorSnackBar(context);
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '$quantity ${widget.item.unit} added to ${widget.item.displayName}',
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
        label: 'Quantity received (${widget.item.unit})',
        controller: _quantityController,
        validator: (value) => (value == null || value.isEmpty)
            ? 'Enter the quantity received.'
            : null,
      ),
      AppTextField(
        label: 'Note (optional)',
        controller: _noteController,
        helperText: 'e.g. supplier or delivery reference',
      ),
      AppOptionalDateField(
        label: 'Expiry date (optional)',
        value: _expiryDate,
        firstDate: DateTime.now(),
        onChanged: (value) => setState(() => _expiryDate = value),
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: Text('Add stock — ${widget.item.displayName}')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: ResponsiveCenter(
            maxWidth: 680,
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  AppFormGrid(fields: fields),
                  const SizedBox(height: AppSpacing.xl),
                  AppButton(
                    label: 'Add stock',
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
