import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/payment_channel.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/action_error.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_dropdown_field.dart';
import '../../../../core/widgets/app_inline_alert.dart';
import '../../../../core/widgets/app_stat.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/responsive_center.dart';
import '../../../inventory/data/models/stock_item.dart';
import '../../../inventory/data/providers/inventory_providers.dart';
import '../../data/models/purchase.dart';
import '../../data/models/supplier.dart';
import '../../data/providers/purchases_providers.dart';
import '../widgets/add_supplier_dialog.dart';
import '../widgets/purchase_line_editor.dart';

/// Records raw materials bought: supplier, date, items with prices, and
/// how much was paid now (the rest is owed to the supplier).
class RecordPurchaseScreen extends ConsumerStatefulWidget {
  const RecordPurchaseScreen({super.key});

  @override
  ConsumerState<RecordPurchaseScreen> createState() =>
      _RecordPurchaseScreenState();
}

class _RecordPurchaseScreenState extends ConsumerState<RecordPurchaseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _lines = [PurchaseLineFormData()];
  final _paid = TextEditingController();
  final _note = TextEditingController();
  Supplier? _supplier;
  DateTime _date = DateTime.now();
  PaymentChannel _channel = PaymentChannel.cash;

  @override
  void initState() {
    super.initState();
    _listen(_lines.first);
    _paid.addListener(_refresh);
  }

  void _refresh() => setState(() {});

  void _listen(PurchaseLineFormData line) {
    line.quantity.addListener(_refresh);
    line.unitCost.addListener(_refresh);
  }

  @override
  void dispose() {
    for (final line in _lines) {
      line.dispose();
    }
    _paid.dispose();
    _note.dispose();
    super.dispose();
  }

  void _remove(PurchaseLineFormData line) {
    setState(() => _lines.remove(line));
    // Its fields are still on screen until this rebuild finishes.
    WidgetsBinding.instance.addPostFrameCallback((_) => line.dispose());
  }

  num get _total => _lines.fold<num>(0, (sum, l) => sum + l.lineTotal);
  num get _paidValue => parseNairaText(_paid.text);

  Future<void> _newSupplier() async {
    final supplier = await showAddSupplierDialog(context);
    if (supplier != null) setState(() => _supplier = supplier);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_supplier == null || _lines.any((l) => l.item == null)) {
      showActionErrorSnackBar(
        context,
        message: 'Choose the supplier and a raw material on every line.',
      );
      return;
    }
    final saved = await ref
        .read(purchaseActionControllerProvider.notifier)
        .recordPurchase(
          supplierId: _supplier!.id,
          date: _date,
          lines: [
            for (final line in _lines)
              PurchaseLine(
                itemId: line.item!.id,
                itemName: line.item!.name,
                unit: line.item!.unit,
                quantity: line.quantityValue,
                unitCost: line.unitCostValue,
              ),
          ],
          amountPaid: _paidValue,
          paidChannel: _paidValue > 0 ? _channel : null,
          note: _note.text.trim().isEmpty ? null : _note.text.trim(),
        );
    if (!saved || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Purchase recorded: ${formatNaira(_total)}.')),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final suppliers = ref.watch(suppliersProvider).valueOrNull ?? const [];
    final materials = (ref.watch(stockItemsProvider).valueOrNull ?? const [])
        .where((i) => i.category == StockCategory.rawMaterial)
        .toList();
    final state = ref.watch(purchaseActionControllerProvider);
    final error = state.hasError ? readableErrorMessage(state.error) : null;
    final owed = _total - _paidValue;

    return Scaffold(
      appBar: AppBar(title: const Text('Record purchase')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: ResponsiveCenter(
          maxWidth: 720,
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: AppDropdownField<Supplier?>(
                        label: 'Supplier',
                        value: suppliers.contains(_supplier) ? _supplier : null,
                        items: [null, ...suppliers],
                        itemLabel: (s) => s?.name ?? 'Choose a supplier',
                        onChanged: (s) => setState(() => _supplier = s),
                      ),
                    ),
                    AppButton(
                      label: 'New',
                      leadingIcon: Icons.add,
                      variant: AppButtonVariant.text,
                      onPressed: _newSupplier,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                AppButton(
                  label: DateFormat.yMMMd().format(_date),
                  leadingIcon: Icons.calendar_today_outlined,
                  variant: AppButtonVariant.secondary,
                  onPressed: _pickDate,
                ),
                const SizedBox(height: AppSpacing.lg),
                for (final line in _lines) ...[
                  PurchaseLineEditor(
                    line: line,
                    materials: materials,
                    onChanged: _refresh,
                    onRemove: _lines.length > 1 ? () => _remove(line) : null,
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                AppButton(
                  label: 'Add another item',
                  leadingIcon: Icons.add,
                  variant: AppButtonVariant.text,
                  onPressed: () => setState(() {
                    final line = PurchaseLineFormData();
                    _listen(line);
                    _lines.add(line);
                  }),
                ),
                const SizedBox(height: AppSpacing.md),
                AppStat(label: 'Total', value: formatNaira(_total)),
                const SizedBox(height: AppSpacing.lg),
                AppTextField.naira(
                  label: 'Paid now (leave 0 if bought on credit)',
                  controller: _paid,
                  validator: (_) => _paidValue > _total
                      ? "Paid can't be more than the total"
                      : null,
                ),
                if (_paidValue > 0) ...[
                  const SizedBox(height: AppSpacing.md),
                  AppDropdownField<PaymentChannel>(
                    label: 'Paid by',
                    value: _channel,
                    items: PaymentChannel.values,
                    itemLabel: (c) => c.label,
                    onChanged: (c) => setState(() => _channel = c!),
                  ),
                ],
                if (owed > 0) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text('${formatNaira(owed)} will be owed to the supplier.'),
                ],
                const SizedBox(height: AppSpacing.md),
                AppTextField(label: 'Note (optional)', controller: _note),
                if (error != null) ...[
                  const SizedBox(height: AppSpacing.lg),
                  AppInlineAlert(message: error),
                ],
                const SizedBox(height: AppSpacing.xl),
                AppButton(
                  label: 'Record purchase',
                  isLoading: state.isLoading,
                  expanded: true,
                  onPressed: state.isLoading ? null : _save,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
