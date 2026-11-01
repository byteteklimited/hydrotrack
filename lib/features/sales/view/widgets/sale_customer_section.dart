import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../data/models/sale.dart';
import '../../data/providers/sales_providers.dart';
import 'distributor_picker_sheet.dart';

/// Customer-type toggle, plus the distributor picker when the type is
/// Distributor.
class SaleCustomerSection extends ConsumerWidget {
  const SaleCustomerSection({
    super.key,
    required this.customerType,
    required this.distributorName,
    required this.onCustomerTypeChanged,
    required this.onDistributorSelected,
  });

  final CustomerType customerType;
  final String? distributorName;
  final ValueChanged<CustomerType> onCustomerTypeChanged;
  final ValueChanged<String> onDistributorSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SegmentedButton<CustomerType>(
          segments: const [
            ButtonSegment(value: CustomerType.walkIn, label: Text('Walk-in')),
            ButtonSegment(
              value: CustomerType.distributor,
              label: Text('Distributor'),
            ),
          ],
          selected: {customerType},
          onSelectionChanged: (selection) =>
              onCustomerTypeChanged(selection.first),
        ),
        if (customerType == CustomerType.distributor) ...[
          const SizedBox(height: AppSpacing.md),
          ref
              .watch(distributorNamesProvider)
              .when(
                data: (names) => AppButton(
                  label: distributorName ?? 'Select distributor',
                  variant: AppButtonVariant.secondary,
                  leadingIcon: Icons.storefront_outlined,
                  expanded: true,
                  onPressed: () async {
                    final picked = await showDistributorPicker(context, names);
                    if (picked != null) onDistributorSelected(picked);
                  },
                ),
                loading: () => const AppLoadingCompact(),
                error: (error, stackTrace) => const SizedBox.shrink(),
              ),
        ],
      ],
    );
  }
}
