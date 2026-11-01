import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/action_error.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../data/models/sale.dart';
import '../../data/providers/sales_providers.dart';

/// Opens the "Void sale" dialog for [sale]. A reason is required — the
/// RPC enforces this too, but failing fast client-side avoids a
/// pointless round trip.
Future<void> showVoidSaleDialog(BuildContext context, Sale sale) {
  return showDialog<void>(
    context: context,
    builder: (context) => VoidSaleDialog(sale: sale),
  );
}

class VoidSaleDialog extends ConsumerStatefulWidget {
  const VoidSaleDialog({super.key, required this.sale});

  final Sale sale;

  @override
  ConsumerState<VoidSaleDialog> createState() => _VoidSaleDialogState();
}

class _VoidSaleDialogState extends ConsumerState<VoidSaleDialog> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _void() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final reason = _reasonController.text.trim();

    await ref
        .read(voidSaleControllerProvider.notifier)
        .voidSale(saleId: widget.sale.id, reason: reason);
    if (!mounted) return;

    final state = ref.read(voidSaleControllerProvider);
    if (state.hasError) {
      final error = state.error;
      final message = readableErrorMessage(error);
      showActionErrorSnackBar(context, message: message);
      return;
    }

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isVoiding = ref.watch(voidSaleControllerProvider).isLoading;

    return AlertDialog(
      title: const Text('Void this sale?'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Stock, any debt this created, and any cash it recorded are '
              "all reversed. The sale stays on record, marked voided — "
              "this can't be undone.",
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              label: 'Reason',
              controller: _reasonController,
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? 'A reason is required to void a sale.'
                  : null,
            ),
          ],
        ),
      ),
      actions: [
        AppButton(
          label: 'Cancel',
          variant: AppButtonVariant.text,
          onPressed: isVoiding ? null : () => Navigator.of(context).pop(),
        ),
        AppButton(
          label: 'Void sale',
          isLoading: isVoiding,
          onPressed: isVoiding ? null : _void,
        ),
      ],
    );
  }
}
