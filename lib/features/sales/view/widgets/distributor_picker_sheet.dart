import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_text_field.dart';

/// Searchable bottom sheet for picking a distributor from the mock
/// directory. Returns the selected name via [Navigator.pop].
Future<String?> showDistributorPicker(
  BuildContext context,
  List<String> names,
) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _DistributorPickerSheet(names: names),
  );
}

class _DistributorPickerSheet extends StatefulWidget {
  const _DistributorPickerSheet({required this.names});

  final List<String> names;

  @override
  State<_DistributorPickerSheet> createState() =>
      _DistributorPickerSheetState();
}

class _DistributorPickerSheetState extends State<_DistributorPickerSheet> {
  final _searchController = TextEditingController();
  late List<String> _filtered = widget.names;

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
      _filtered = widget.names
          .where((name) => name.toLowerCase().contains(query))
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
              'Select distributor',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              label: 'Search distributors',
              controller: _searchController,
              prefixIcon: const Icon(Icons.search),
            ),
            const SizedBox(height: AppSpacing.sm),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 320),
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final name in _filtered)
                    ListTile(
                      title: Text(name),
                      onTap: () => Navigator.of(context).pop(name),
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
