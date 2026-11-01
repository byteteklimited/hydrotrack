import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/action_error.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_dropdown_field.dart';
import '../../../../core/widgets/app_form_grid.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/responsive_center.dart';
import '../../data/models/stock_item.dart';
import '../../data/providers/inventory_providers.dart';

/// Adds a new item to the inventory catalog, or — when [existingItem] is
/// given — edits one already there (Admin/Manager only either way).
/// Category and the product-type link are fixed at creation: changing
/// either after the fact risks breaking the load-out deduction a
/// finished-goods item may already depend on, so editing only touches
/// name/unit/reorder level.
class AddStockItemScreen extends ConsumerStatefulWidget {
  const AddStockItemScreen({super.key, this.existingItem});

  final StockItem? existingItem;

  @override
  ConsumerState<AddStockItemScreen> createState() => _AddStockItemScreenState();
}

class _AddStockItemScreenState extends ConsumerState<AddStockItemScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(
    text: widget.existingItem?.name,
  );
  late final _unitController = TextEditingController(
    text: widget.existingItem?.unit,
  );
  late final _reorderLevelController = TextEditingController(
    text: widget.existingItem?.reorderLevel.toString(),
  );

  late StockCategory _category =
      widget.existingItem?.category ?? StockCategory.rawMaterial;
  late ProductType? _productType = widget.existingItem?.productType;

  bool get _isEditing => widget.existingItem != null;

  @override
  void dispose() {
    _nameController.dispose();
    _unitController.dispose();
    _reorderLevelController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final controller = ref.read(stockActionControllerProvider.notifier);
    final name = _nameController.text.trim();
    final unit = _unitController.text.trim();
    final reorderLevel = int.parse(_reorderLevelController.text);

    final result = _isEditing
        ? await controller.updateItemDetails(
            itemId: widget.existingItem!.id,
            name: name,
            unit: unit,
            reorderLevel: reorderLevel,
          )
        : await controller.createItem(
            name: name,
            category: _category,
            unit: unit,
            reorderLevel: reorderLevel,
            productType: _productType,
          );
    if (!mounted) return;

    if (result == null) {
      showActionErrorSnackBar(context);
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_isEditing ? '$name updated' : '$name added')),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isSaving = ref.watch(stockActionControllerProvider).isLoading;

    // Each product type can only back one finished-goods item at a
    // time — offer the ones nothing else already claims, plus whatever
    // this item already has (irrelevant in practice since it's add-only,
    // but keeps the dropdown correct if that ever changes).
    final claimedTypes =
        ref
            .watch(stockItemsProvider)
            .valueOrNull
            ?.where((i) => i.id != widget.existingItem?.id)
            .map((i) => i.productType)
            .whereType<ProductType>()
            .toSet() ??
        const <ProductType>{};
    final availableProductTypes = ProductType.values
        .where((p) => !claimedTypes.contains(p))
        .toList();

    final fields = <Widget>[
      AppTextField(
        label: 'Name',
        controller: _nameController,
        validator: (value) => (value == null || value.trim().isEmpty)
            ? "Enter the item's name."
            : null,
      ),
      if (_isEditing)
        AppTextField(
          label: 'Category',
          controller: TextEditingController(text: _category.label),
          enabled: false,
        )
      else
        AppDropdownField<StockCategory>(
          label: 'Category',
          value: _category,
          items: StockCategory.values,
          itemLabel: (category) => category.label,
          onChanged: (value) => setState(() {
            _category = value!;
            if (_category == StockCategory.rawMaterial) _productType = null;
          }),
        ),
      AppTextField(
        label: 'Unit',
        controller: _unitController,
        helperText: 'e.g. pcs, rolls, litres, bags',
        validator: (value) => (value == null || value.trim().isEmpty)
            ? 'Enter the unit this is counted in.'
            : null,
      ),
      AppTextField.quantity(
        label: 'Reorder level',
        controller: _reorderLevelController,
        helperText: 'Flag as running low at or below this count',
        validator: (value) =>
            (value == null || value.isEmpty) ? 'Enter a reorder level.' : null,
      ),
      if (!_isEditing && _category == StockCategory.finishedGoods)
        AppDropdownField<ProductType?>(
          label: 'Linked product (optional)',
          value: _productType,
          items: [null, ...availableProductTypes],
          itemLabel: (type) => type?.label ?? 'None',
          onChanged: (value) => setState(() => _productType = value),
        ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit item' : 'Add inventory item'),
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
                  AppFormGrid(fields: fields),
                  const SizedBox(height: AppSpacing.xl),
                  AppButton(
                    label: _isEditing ? 'Save changes' : 'Add item',
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
