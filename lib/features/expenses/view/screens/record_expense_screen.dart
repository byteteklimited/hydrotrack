import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/action_error.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_dropdown_field.dart';
import '../../../../core/widgets/app_form_grid.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/responsive_center.dart';
import '../../../auth/data/providers/auth_providers.dart';
import '../../data/models/expense.dart';
import '../../data/providers/expenses_providers.dart';

/// Records a new expense.
class RecordExpenseScreen extends ConsumerStatefulWidget {
  const RecordExpenseScreen({super.key});

  @override
  ConsumerState<RecordExpenseScreen> createState() =>
      _RecordExpenseScreenState();
}

class _RecordExpenseScreenState extends ConsumerState<RecordExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();

  ExpenseCategory _category = ExpenseCategory.fuelDiesel;
  PaymentChannel _method = PaymentChannel.cash;
  DateTime _date = DateTime.now();

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 180)),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final user = ref.read(authStateProvider);
    final expense = Expense(
      id: 'exp-${DateTime.now().microsecondsSinceEpoch}',
      date: _date,
      category: _category,
      description: _descriptionController.text.trim(),
      amount: num.tryParse(_amountController.text.replaceAll(',', '')) ?? 0,
      method: _method,
      recordedBy: user?.fullName ?? 'Unknown',
    );

    await ref.read(recordExpenseControllerProvider.notifier).record(expense);
    if (!mounted) return;

    if (ref.read(recordExpenseControllerProvider).hasError) {
      showActionErrorSnackBar(context);
      return;
    }

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isSaving = ref.watch(recordExpenseControllerProvider).isLoading;

    final fields = [
      AppDropdownField<ExpenseCategory>(
        label: 'Category',
        value: _category,
        items: ExpenseCategory.values,
        itemLabel: (category) => category.label,
        onChanged: (category) => setState(() => _category = category!),
      ),
      AppTextField(
        hint: 'e.g. Fuel for the bus',
        label: 'What was it for?',
        controller: _descriptionController,
        validator: (value) => (value == null || value.trim().isEmpty)
            ? 'Describe what this expense was for.'
            : null,
      ),
      AppTextField.naira(
        hint: 'e.g. 5,000',
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
      AppButton(
        label: DateFormat.yMMMd().format(_date),
        leadingIcon: Icons.calendar_today_outlined,
        variant: AppButtonVariant.secondary,
        expanded: true,
        onPressed: _pickDate,
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Record expense')),
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
                      AppFormGrid(fields: fields),
                      const SizedBox(height: AppSpacing.xl),
                      AppButton(
                        label: 'Record expense',
                        isLoading: isSaving,
                        expanded: true,
                        onPressed: isSaving ? null : _submit,
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
