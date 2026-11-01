import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_dropdown_field.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../inventory/data/models/stock_item.dart';

/// One item being bought: which raw material, how many, at what price.
class PurchaseLineFormData {
  StockItem? item;
  final quantity = TextEditingController();
  final unitCost = TextEditingController();

  int get quantityValue => int.tryParse(quantity.text) ?? 0;
  num get unitCostValue => parseNairaText(unitCost.text);
  num get lineTotal => quantityValue * unitCostValue;

  void dispose() {
    quantity.dispose();
    unitCost.dispose();
  }
}

class PurchaseLineEditor extends StatelessWidget {
  const PurchaseLineEditor({
    super.key,
    required this.line,
    required this.materials,
    required this.onChanged,
    this.onRemove,
  });

  final PurchaseLineFormData line;
  final List<StockItem> materials;
  final VoidCallback onChanged;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: AppDropdownField<StockItem?>(
                label: 'Raw material',
                value: line.item,
                items: [null, ...materials],
                itemLabel: (item) => item?.name ?? 'Choose a raw material',
                onChanged: (item) {
                  line.item = item;
                  onChanged();
                },
              ),
            ),
            if (onRemove != null)
              IconButton(
                icon: const Icon(Icons.close),
                tooltip: 'Remove item',
                onPressed: onRemove,
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: AppTextField.quantity(
                label:
                    'Quantity${line.item == null ? '' : ' (${line.item!.unit})'}',
                controller: line.quantity,
                validator: (v) =>
                    (int.tryParse(v ?? '') ?? 0) > 0 ? null : 'Enter how many',
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: AppTextField.naira(
                label: 'Price each',
                controller: line.unitCost,
                validator: (v) => Validators.required(v, 'Enter the price'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
