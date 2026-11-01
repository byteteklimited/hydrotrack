import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_modal.dart';
import '../../data/providers/purchases_providers.dart';
import '../screens/supplier_detail_screen.dart';
import 'add_supplier_dialog.dart';

/// Every supplier and what we owe them; tap one for their account.
class SuppliersCard extends ConsumerWidget {
  const SuppliersCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final suppliers = ref.watch(suppliersProvider).valueOrNull ?? const [];
    final owed = suppliers.fold<num>(0, (sum, s) => sum + s.balance);

    return AppCard(
      title: suppliers.isEmpty
          ? 'Suppliers'
          : 'Suppliers · we owe ${formatNaira(owed)}',
      trailing: AppButton(
        label: 'Add supplier',
        variant: AppButtonVariant.text,
        onPressed: () => showAddSupplierDialog(context),
      ),
      child: Column(
        children: [
          if (suppliers.isEmpty)
            const Text(
              'Add the people you buy nylon, preforms, caps and '
              'chemicals from.',
            ),
          for (final supplier in suppliers)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(supplier.name),
              subtitle: supplier.phone == null ? null : Text(supplier.phone!),
              trailing: Text(
                supplier.balance > 0
                    ? 'Owe ${formatNaira(supplier.balance)}'
                    : 'Settled',
                style: TextStyle(
                  color: supplier.balance > 0
                      ? AppColors.lowStockWarning
                      : AppColors.textSecondary,
                ),
              ),
              onTap: () => showAppModal<void>(
                context,
                builder: (_) => SupplierDetailScreen(supplierId: supplier.id),
              ),
            ),
        ],
      ),
    );
  }
}
