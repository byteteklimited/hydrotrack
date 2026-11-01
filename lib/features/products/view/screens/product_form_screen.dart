import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/action_error.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_form_grid.dart';
import '../../../../core/widgets/app_inline_alert.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/responsive_center.dart';
import '../../data/models/product.dart';
import '../../data/providers/products_providers.dart';
import '../widgets/product_status_actions.dart';

/// Adds a product, or edits one ([product] given): name, unit and the two
/// prices, plus retire / bring back / delete.
class ProductFormScreen extends ConsumerStatefulWidget {
  const ProductFormScreen({super.key, this.product});

  final Product? product;

  @override
  ConsumerState<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends ConsumerState<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  static final _naira = NumberFormat.decimalPattern('en_NG');
  late final _name = TextEditingController(text: widget.product?.name);
  late final _unit = TextEditingController(
    text: widget.product?.unit ?? 'bags',
  );
  late final _walkIn = TextEditingController(
    text: widget.product == null
        ? null
        : _naira.format(widget.product!.walkInPrice),
  );
  late final _distributor = TextEditingController(
    text: widget.product == null
        ? null
        : _naira.format(widget.product!.distributorPrice),
  );

  @override
  void dispose() {
    for (final controller in [_name, _unit, _walkIn, _distributor]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final saved = await ref
        .read(productActionControllerProvider.notifier)
        .save(
          productId: widget.product?.id,
          name: _name.text.trim(),
          unit: _unit.text.trim(),
          walkInPrice: parseNairaText(_walkIn.text),
          distributorPrice: parseNairaText(_distributor.text),
        );
    if (saved == null || !mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('${saved.name} saved.')));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(productActionControllerProvider);
    final error = state.hasError
        ? readableErrorMessage(state.error) ??
              "Couldn't save. Check your connection and try again."
        : null;
    String? price(String? value) =>
        Validators.required(value, 'Enter a price (0 if not sold this way)');

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.product == null ? 'Add product' : 'Edit product'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: ResponsiveCenter(
          maxWidth: 680,
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppFormGrid(
                  fields: [
                    AppTextField(
                      label: 'Name',
                      controller: _name,
                      helperText: 'e.g. 50cl Sachet, 19L Dispenser Bottle',
                      validator: (v) => Validators.required(v, 'Enter a name'),
                    ),
                    AppTextField(
                      label: 'Sold in',
                      controller: _unit,
                      helperText: 'e.g. bags, packs, bottles',
                      validator: (v) =>
                          Validators.required(v, 'Enter the unit'),
                    ),
                    AppTextField.naira(
                      label: 'Walk-in price',
                      controller: _walkIn,
                      validator: price,
                    ),
                    AppTextField.naira(
                      label: 'Distributor price',
                      controller: _distributor,
                      validator: price,
                    ),
                  ],
                ),
                if (error != null) ...[
                  const SizedBox(height: AppSpacing.lg),
                  AppInlineAlert(message: error),
                ],
                const SizedBox(height: AppSpacing.xl),
                AppButton(
                  label: 'Save product',
                  isLoading: state.isLoading,
                  expanded: true,
                  onPressed: state.isLoading ? null : _save,
                ),
                if (widget.product != null) ...[
                  const SizedBox(height: AppSpacing.lg),
                  ProductStatusActions(product: widget.product!),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
