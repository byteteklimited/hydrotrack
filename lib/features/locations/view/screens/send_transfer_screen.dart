import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/action_error.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_dropdown_field.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../inventory/data/models/stock_item.dart';
import '../../../inventory/data/providers/inventory_providers.dart';
import '../../data/models/location.dart';
import '../../data/providers/location_providers.dart';
import '../../data/providers/transfer_providers.dart';

/// Sends stock from the current location to another. It leaves stock
/// here straight away and arrives when the other location receives it.
class SendTransferScreen extends ConsumerStatefulWidget {
  const SendTransferScreen({super.key});

  @override
  ConsumerState<SendTransferScreen> createState() => _SendTransferScreenState();
}

class _SendTransferScreenState extends ConsumerState<SendTransferScreen> {
  final _formKey = GlobalKey<FormState>();
  final _note = TextEditingController();
  final Map<String, TextEditingController> _quantities = {};
  String? _toId;

  @override
  void dispose() {
    _note.dispose();
    for (final field in _quantities.values) {
      field.dispose();
    }
    super.dispose();
  }

  TextEditingController _field(String itemId) =>
      _quantities.putIfAbsent(itemId, TextEditingController.new);

  Future<void> _send(String toId) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final quantities = {
      for (final entry in _quantities.entries)
        if ((int.tryParse(entry.value.text) ?? 0) > 0)
          entry.key: int.parse(entry.value.text),
    };
    if (quantities.isEmpty) {
      showActionErrorSnackBar(context, message: 'Enter how much to send');
      return;
    }
    final sent = await ref
        .read(transfersActionControllerProvider.notifier)
        .send(
          toLocationId: toId,
          quantities: quantities,
          note: _note.text.trim().isEmpty ? null : _note.text.trim(),
        );
    if (!mounted) return;
    if (!sent) {
      showActionErrorSnackBar(
        context,
        message: readableErrorMessage(
          ref.read(transfersActionControllerProvider).error,
        ),
      );
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final busy = ref.watch(transfersActionControllerProvider).isLoading;
    final here = ref.watch(currentLocationProvider);
    final destinations = [
      for (final location
          in ref.watch(allLocationsProvider).valueOrNull ?? const <Location>[])
        if (location.isActive && location != here) location,
    ];
    final items = [
      for (final item
          in ref.watch(stockItemsProvider).valueOrNull ?? const <StockItem>[])
        if (item.quantityOnHand > 0) item,
    ];
    final toId = _toId ?? destinations.firstOrNull?.id;

    return Scaffold(
      appBar: AppBar(title: Text('Send stock from ${here?.name ?? ''}')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            if (toId == null)
              const Text('There is no other location to send to yet.')
            else ...[
              AppDropdownField<String>(
                label: 'Send to',
                value: toId,
                items: [for (final l in destinations) l.id],
                itemLabel: (id) =>
                    destinations.firstWhere((l) => l.id == id).name,
                onChanged: (id) => setState(() => _toId = id),
              ),
              const SizedBox(height: AppSpacing.lg),
              if (items.isEmpty) const Text('Nothing in stock here to send.'),
              for (final item in items)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: AppTextField.quantity(
                    label: item.displayName,
                    controller: _field(item.id),
                    unit: item.unit,
                    helperText:
                        'Have ${formatQuantity(item.quantityOnHand, item.unit)}',
                    validator: (v) =>
                        (int.tryParse(v ?? '') ?? 0) > item.quantityOnHand
                        ? 'Only ${item.quantityOnHand} here'
                        : null,
                  ),
                ),
              AppTextField(label: 'Note (optional)', controller: _note),
              const SizedBox(height: AppSpacing.lg),
              AppButton(
                label: 'Send stock',
                isLoading: busy,
                onPressed: busy ? null : () => _send(toId),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
