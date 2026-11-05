import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/action_error.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_dropdown_field.dart';
import '../../../../core/widgets/app_form_grid.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/responsive_center.dart';
import '../../../inventory/data/models/stock_item.dart';
import '../../../inventory/data/providers/inventory_providers.dart';
import '../../../products/data/providers/products_providers.dart';
import '../../data/models/production_recipe.dart';
import '../../data/providers/production_recipe_providers.dart';

/// Adds a new bill-of-materials line, or — when [existingLine] is given —
/// corrects its ratio (Admin/Manager only either way). Which product and
/// which raw material a line is for are fixed once created: changing
/// either is really a different line, so editing only touches the
/// quantities.
class AddRecipeLineScreen extends ConsumerStatefulWidget {
  const AddRecipeLineScreen({super.key, this.existingLine});

  final ProductionRecipe? existingLine;

  @override
  ConsumerState<AddRecipeLineScreen> createState() =>
      _AddRecipeLineScreenState();
}

class _AddRecipeLineScreenState extends ConsumerState<AddRecipeLineScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _quantityUsedController = TextEditingController(
    text: widget.existingLine?.quantityUsed.toString(),
  );
  late final _perBagsController = TextEditingController(
    text: widget.existingLine?.perBags.toString(),
  );

  late Product? _product = widget.existingLine?.product;
  late String? _rawMaterialItemId = widget.existingLine?.rawMaterialItemId;

  bool get _isEditing => widget.existingLine != null;

  @override
  void dispose() {
    _quantityUsedController.dispose();
    _perBagsController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_product == null || _rawMaterialItemId == null) return;

    final success = await ref
        .read(recipeActionControllerProvider.notifier)
        .saveLine(
          product: _product!,
          rawMaterialItemId: _rawMaterialItemId!,
          quantityUsed: double.parse(_quantityUsedController.text),
          perBags: int.parse(_perBagsController.text),
        );
    if (!mounted) return;

    if (!success) {
      showActionErrorSnackBar(context);
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_isEditing ? 'Recipe line updated' : 'Recipe line added'),
      ),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isSaving = ref.watch(recipeActionControllerProvider).isLoading;
    final products =
        ref.watch(activeProductsProvider).valueOrNull ?? const <Product>[];
    final rawMaterials =
        ref
            .watch(stockItemsProvider)
            .valueOrNull
            ?.where((item) => item.category == StockCategory.rawMaterial)
            .toList() ??
        const <StockItem>[];

    final selectedUnit = rawMaterials
        .where((item) => item.id == _rawMaterialItemId)
        .map((item) => item.unit)
        .firstOrNull;

    final fields = <Widget>[
      if (_isEditing)
        AppTextField(
          hint: 'e.g. 50cl sachet',
          label: 'Product',
          controller: TextEditingController(text: _product!.label),
          enabled: false,
        )
      else
        AppDropdownField<Product?>(
          label: 'Product',
          value: _product,
          items: [null, ...products],
          itemLabel: (product) => product?.label ?? 'Select a product',
          onChanged: (value) => setState(() => _product = value),
        ),
      if (_isEditing)
        AppTextField(
          hint: 'e.g. Nylon roll',
          label: 'Raw material',
          controller: TextEditingController(
            text: widget.existingLine!.rawMaterialName,
          ),
          enabled: false,
        )
      else
        AppDropdownField<String?>(
          label: 'Raw material',
          value: _rawMaterialItemId,
          items: [null, ...rawMaterials.map((item) => item.id)],
          itemLabel: (id) => id == null
              ? 'Select a raw material'
              : rawMaterials.firstWhere((item) => item.id == id).name,
          onChanged: (value) => setState(() => _rawMaterialItemId = value),
        ),
      AppTextField.decimal(
        hint: 'e.g. 1',
        label: 'Quantity used',
        controller: _quantityUsedController,
        helperText: selectedUnit == null ? null : 'In $selectedUnit',
        validator: (value) {
          final parsed = double.tryParse(value ?? '');
          return (parsed == null || parsed <= 0)
              ? 'Enter how much is used.'
              : null;
        },
      ),
      AppTextField.quantity(
        hint: 'e.g. 40',
        label: 'Makes how many bags',
        controller: _perBagsController,
        helperText: 'Produced + wastage, combined',
        validator: (value) {
          final parsed = int.tryParse(value ?? '');
          return (parsed == null || parsed <= 0)
              ? 'Enter how many bags that quantity makes.'
              : null;
        },
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit recipe line' : 'Add recipe line'),
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
                    label: _isEditing ? 'Save changes' : 'Add line',
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
