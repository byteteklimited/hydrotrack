import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/action_error.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_dropdown_field.dart';
import '../../../../core/widgets/app_form_grid.dart';
import '../../../../core/widgets/app_inline_alert.dart';
import '../../../../core/widgets/app_optional_date_field.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/responsive_center.dart';
import '../../../auth/data/providers/auth_providers.dart';
import '../../../inventory/data/providers/inventory_providers.dart';
import '../../../machines/data/models/machine.dart';
import '../../../machines/data/providers/machines_providers.dart';
import '../../../products/data/providers/products_providers.dart';
import '../../data/models/production_run.dart';
import '../../data/providers/production_providers.dart';
import '../../data/providers/production_recipe_providers.dart';

/// Records a new production run, or — when [existingRun] is given — edits
/// one already recorded (Admin/Manager only; the detail screen only shows
/// the edit action to those roles). Same form either way: same fields,
/// same validation, same grid layout.
class RecordProductionScreen extends ConsumerStatefulWidget {
  const RecordProductionScreen({super.key, this.existingRun});

  final ProductionRun? existingRun;

  @override
  ConsumerState<RecordProductionScreen> createState() =>
      _RecordProductionScreenState();
}

class _RecordProductionScreenState
    extends ConsumerState<RecordProductionScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _operatorController = TextEditingController(
    text: widget.existingRun?.operatorName,
  );
  late final _quantityController = TextEditingController(
    text: widget.existingRun?.quantityProduced.toString(),
  );
  late final _wastageController = TextEditingController(
    text: widget.existingRun?.wastage.toString(),
  );

  late DateTime _date = widget.existingRun?.date ?? DateTime.now();
  late ProductionShift _shift =
      widget.existingRun?.shift ?? ProductionShift.morning;

  /// Null until chosen: the first machine in the list is used.
  late String? _chosenMachine = widget.existingRun?.machine;

  /// What can be picked: the organization's machines in use (not the
  /// generator), plus the run's own machine if it isn't one of them.
  List<String> _machineChoices(WidgetRef ref) {
    final machines =
        ref.watch(activeMachinesProvider).valueOrNull ?? const <Machine>[];
    final names = [
      for (final machine in machines)
        if (machine.kind != MachineKind.generator) machine.name,
    ];
    final own = widget.existingRun?.machine;
    return [if (own != null && !names.contains(own)) own, ...names];
  }

  String get _machine =>
      _chosenMachine ?? _machineChoices(ref).firstOrNull ?? '';

  /// Null until chosen: the first active product is used.
  late Product? _chosenProduct = widget.existingRun?.product;

  /// What can be picked: active products, plus the run's own product if
  /// it has since been retired.
  List<Product> _productChoices(WidgetRef ref) {
    final active =
        ref.watch(activeProductsProvider).valueOrNull ?? const <Product>[];
    final own = widget.existingRun?.product;
    return [if (own != null && !active.contains(own)) own, ...active];
  }

  Product? _product(WidgetRef ref) =>
      _chosenProduct ?? _productChoices(ref).firstOrNull;

  // Not prefilled when editing — a run's output batch is looked up by
  // product, not stored on the run itself, and re-deriving it here
  // would need an extra async round trip for a field most edits won't
  // touch. Re-enter it if you're editing a run that already has one.
  DateTime? _expiryDate;

  bool get _isEditing => widget.existingRun != null;

  @override
  void initState() {
    super.initState();
    // The raw-material shortage check reads these live, so typing needs
    // to re-run it — the form has no other reason to rebuild per
    // keystroke.
    _quantityController.addListener(_onQuantityOrWastageChanged);
    _wastageController.addListener(_onQuantityOrWastageChanged);
  }

  void _onQuantityOrWastageChanged() => setState(() {});

  @override
  void dispose() {
    _operatorController.dispose();
    _quantityController.dispose();
    _wastageController.dispose();
    super.dispose();
  }

  /// Mirrors the server's own check in `record_production_run`/
  /// `update_production_run` (supabase/migrations/0006_business_rpcs.sql) so the form can block
  /// before a submit round-trip, not just report the RPC's rejection
  /// after the fact. Editing a run first frees up whatever it already
  /// consumed — approximated here by crediting back this run's
  /// *original* recipe-based need when the product hasn't also changed;
  /// if the product itself is being changed mid-edit, that credit isn't
  /// applied and the check may be overly conservative in that one rare
  /// case. The server is the actual source of truth either way.
  List<String> _rawMaterialShortages(WidgetRef ref) {
    final recipes = ref.watch(productionRecipesProvider).valueOrNull ?? [];
    final stockItems = ref.watch(stockItemsProvider).valueOrNull ?? [];
    final quantityProduced = int.tryParse(_quantityController.text) ?? 0;
    final wastage = int.tryParse(_wastageController.text) ?? 0;
    final totalUnits = quantityProduced + wastage;
    final existing = widget.existingRun;
    final originalTotalUnits = existing == null
        ? 0
        : existing.quantityProduced + existing.wastage;

    final product = _product(ref);
    final shortages = <String>[];
    for (final recipe in recipes.where((r) => r.product == product)) {
      final needed = (recipe.quantityPerBag * totalUnits).round();
      if (needed <= 0) continue;

      final item = stockItems
          .where((i) => i.id == recipe.rawMaterialItemId)
          .firstOrNull;
      var available = item?.quantityOnHand ?? 0;
      if (existing != null && existing.product == product) {
        available += (recipe.quantityPerBag * originalTotalUnits).round();
      }

      if (available < needed) {
        shortages.add(
          '${recipe.rawMaterialName}: need $needed ${recipe.rawMaterialUnit}, '
          'only $available available',
        );
      }
    }
    return shortages;
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final existing = widget.existingRun;
    final user = ref.read(authStateProvider);
    final quantity = int.parse(_quantityController.text);
    final product = _product(ref);
    if (product == null || _machine.isEmpty) return;
    final run = ProductionRun(
      id: existing?.id ?? 'run-${DateTime.now().microsecondsSinceEpoch}',
      date: _date,
      shift: _shift,
      machine: _machine,
      operatorName: _operatorController.text.trim(),
      product: product,
      quantityProduced: quantity,
      wastage: int.parse(_wastageController.text),
      recordedBy: existing?.recordedBy ?? user?.fullName ?? 'Unknown',
      recordedAt: existing?.recordedAt ?? DateTime.now(),
    );

    final controller = ref.read(recordProductionControllerProvider.notifier);
    await (_isEditing
        ? controller.update(run, expiryDate: _expiryDate)
        : controller.record(run, expiryDate: _expiryDate));
    if (!mounted) return;

    if (ref.read(recordProductionControllerProvider).hasError) {
      final error = ref.read(recordProductionControllerProvider).error;
      final reason = readableErrorMessage(error);
      showActionErrorSnackBar(context, message: reason);
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _isEditing
              ? 'Production run updated'
              : 'Production recorded — $quantity bags',
        ),
      ),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isSaving = ref.watch(recordProductionControllerProvider).isLoading;
    final otherRunsToday =
        ref
            .watch(productionRunsProvider)
            .valueOrNull
            ?.where(
              (r) =>
                  r.id != widget.existingRun?.id &&
                  isSameDay(r.date, _date) &&
                  r.shift == _shift &&
                  r.machine == _machine,
            )
            .length ??
        0;
    final hasFinishedGoodsCatalogEntry =
        ref
            .watch(stockItemsProvider)
            .valueOrNull
            ?.any((item) => item.product == _product(ref)) ??
        false;
    final shortages = _rawMaterialShortages(ref);

    final fields = [
      AppButton(
        label: DateFormat.yMMMd().format(_date),
        leadingIcon: Icons.calendar_today_outlined,
        variant: AppButtonVariant.secondary,
        expanded: true,
        onPressed: _pickDate,
      ),
      AppDropdownField<ProductionShift>(
        label: 'Shift',
        value: _shift,
        items: ProductionShift.values,
        itemLabel: (shift) => shift.label,
        onChanged: (value) => setState(() => _shift = value!),
      ),
      if (_machineChoices(ref).isEmpty)
        const AppInlineAlert(
          severity: AppAlertSeverity.warning,
          message:
              'No machines yet. A manager can add them under More → '
              'Machines.',
        )
      else
        AppDropdownField<String>(
          label: 'Machine',
          value: _machine,
          items: _machineChoices(ref),
          itemLabel: (machine) => machine,
          onChanged: (value) => setState(() => _chosenMachine = value),
        ),
      AppDropdownField<Product?>(
        label: 'Product',
        value: _product(ref),
        items: _productChoices(ref),
        itemLabel: (product) => product?.label ?? '',
        onChanged: (value) => setState(() => _chosenProduct = value),
      ),
      AppTextField(
        hint: 'e.g. Sani',
        label: 'Operator',
        controller: _operatorController,
        validator: (value) => (value == null || value.trim().isEmpty)
            ? "Enter the operator's name."
            : null,
      ),
      AppTextField.quantity(
        hint: 'e.g. 250',
        label: 'Bags produced',
        controller: _quantityController,
        validator: (value) => (value == null || value.isEmpty)
            ? 'Enter the number of bags produced.'
            : null,
      ),
      AppTextField.quantity(
        hint: 'e.g. 3',
        label: 'Wastage (bags)',
        controller: _wastageController,
        validator: (value) => (value == null || value.isEmpty)
            ? 'Enter the wastage in bags — use 0 if none.'
            : null,
      ),
      if (hasFinishedGoodsCatalogEntry)
        AppOptionalDateField(
          label: 'Expiry date (optional)',
          value: _expiryDate,
          firstDate: DateTime.now(),
          onChanged: (value) => setState(() => _expiryDate = value),
        ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit production run' : 'Record production'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: ResponsiveCenter(
            maxWidth: 680,
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  if (shortages.isNotEmpty) ...[
                    AppInlineAlert(
                      severity: AppAlertSeverity.error,
                      message:
                          'Not enough raw material to record this run:\n'
                          '${shortages.join('\n')}',
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  if (otherRunsToday > 0) ...[
                    AppInlineAlert(
                      severity: AppAlertSeverity.warning,
                      message:
                          '$_machine already has $otherRunsToday other '
                          '${otherRunsToday == 1 ? 'entry' : 'entries'} for '
                          '${_shift.label} on ${DateFormat.yMMMd().format(_date)}. '
                          "Still correct if this is a separate batch.",
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  AppFormGrid(fields: fields),
                  const SizedBox(height: AppSpacing.xl),
                  AppButton(
                    label: _isEditing ? 'Save changes' : 'Record production',
                    isLoading: isSaving,
                    expanded: true,
                    onPressed: (isSaving || shortages.isNotEmpty)
                        ? null
                        : _submit,
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
