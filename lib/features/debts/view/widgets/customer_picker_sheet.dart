import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../data/models/customer.dart';

/// Searchable bottom sheet for picking a customer to record a payment
/// against — the entry point for "Record payment" from the main Debts
/// list, where no single customer is already in context. Matches by
/// name or area, since most customers share the same city and a route/
/// area is often the faster way to find one.
Future<Customer?> showCustomerPickerSheet(
  BuildContext context,
  List<Customer> customers,
) {
  return showModalBottomSheet<Customer>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _CustomerPickerSheet(customers: customers),
  );
}

class _CustomerPickerSheet extends StatefulWidget {
  const _CustomerPickerSheet({required this.customers});

  final List<Customer> customers;

  @override
  State<_CustomerPickerSheet> createState() => _CustomerPickerSheetState();
}

class _CustomerPickerSheetState extends State<_CustomerPickerSheet> {
  final _searchController = TextEditingController();
  late List<Customer> _filtered = widget.customers;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filtered = widget.customers
          .where(
            (customer) =>
                customer.name.toLowerCase().contains(query) ||
                customer.area.toLowerCase().contains(query),
          )
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.lg,
          right: AppSpacing.lg,
          top: AppSpacing.lg,
          bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select customer',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              hint: 'e.g. Musa or Sabon Gari',
              label: 'Search by name or area',
              controller: _searchController,
              prefixIcon: const Icon(Icons.search),
            ),
            const SizedBox(height: AppSpacing.sm),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 360),
              child: _filtered.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                      child: Text('No customers match that search.'),
                    )
                  : ListView(
                      shrinkWrap: true,
                      children: [
                        for (final customer in _filtered)
                          ListTile(
                            title: Text(customer.name),
                            subtitle: Text(toTitleCase(customer.area)),
                            onTap: () => Navigator.of(context).pop(customer),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
