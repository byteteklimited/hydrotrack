import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/payment_channel.dart';
import '../../../../core/constants/product_catalog.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/action_error.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_inline_alert.dart';
import '../../../../core/widgets/app_stat.dart';
import '../../../../core/widgets/responsive_center.dart';
import '../../../auth/data/providers/auth_providers.dart';
import '../../../inventory/data/providers/inventory_providers.dart';
import '../../data/models/sale.dart';
import '../../data/models/sale_line.dart';
import '../../data/providers/sales_providers.dart';
import '../widgets/sale_customer_section.dart';
import '../widgets/sale_line_form_data.dart';
import '../widgets/sale_lines_section.dart';
import '../widgets/sale_payment_section.dart';

/// Records a new sale: customer, one or more product lines, and how it
/// was paid.
class RecordSaleScreen extends ConsumerStatefulWidget {
  const RecordSaleScreen({super.key});

  @override
  ConsumerState<RecordSaleScreen> createState() => _RecordSaleScreenState();
}

class _RecordSaleScreenState extends ConsumerState<RecordSaleScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountPaidController = TextEditingController();
  final List<SaleLineFormData> _lines = [SaleLineFormData()];

  CustomerType _customerType = CustomerType.walkIn;
  String? _distributorName;
  PaymentMethod _paymentMethod = PaymentMethod.cash;
  PaymentChannel _paidChannel = PaymentChannel.cash;

  @override
  void initState() {
    super.initState();
    _amountPaidController.addListener(_recompute);
    for (final line in _lines) {
      line.quantityController.addListener(_recompute);
      line.unitPriceController.addListener(_recompute);
    }
  }

  @override
  void dispose() {
    _amountPaidController.dispose();
    for (final line in _lines) {
      line.dispose();
    }
    super.dispose();
  }

  void _recompute() => setState(() {});

  num get _total => _lines.fold<num>(0, (sum, line) => sum + line.lineTotal);

  num get _amountPaid => switch (_paymentMethod) {
    PaymentMethod.credit => 0,
    PaymentMethod.part => parseNairaText(_amountPaidController.text),
    PaymentMethod.cash || PaymentMethod.transfer => _total,
  };

  num get _balance => _total - _amountPaid;

  String get _customerLabel =>
      _customerType == CustomerType.distributor && _distributorName != null
      ? _distributorName!
      : 'this customer';

  void _addLine() {
    final line = SaleLineFormData();
    line.quantityController.addListener(_recompute);
    line.unitPriceController.addListener(_recompute);
    setState(() => _lines.add(line));
  }

  void _removeLine(SaleLineFormData line) {
    line.quantityController.removeListener(_recompute);
    line.unitPriceController.removeListener(_recompute);
    line.dispose();
    setState(() => _lines.remove(line));
  }

  void _onLineProductChanged(SaleLineFormData line, ProductType product) {
    setState(() {
      line.product = product;
      line.unitPriceController.text = NumberFormat.decimalPattern(
        'en_NG',
      ).format(product.defaultUnitPrice);
    });
  }

  /// Mirrors the server's own check in `record_sale` (supabase/migrations/0006_business_rpcs.sql) so
  /// the form can block before a submit round-trip. Lines for the same
  /// product are summed together, same as the server does, so two lines
  /// of 50 bags each against 80 in stock correctly reads as short by 20
  /// rather than passing twice independently.
  List<String> _stockShortages(WidgetRef ref) {
    final stockItems = ref.watch(stockItemsProvider).valueOrNull ?? [];

    final neededByProduct = <ProductType, int>{};
    for (final line in _lines) {
      final quantity = int.tryParse(line.quantityController.text) ?? 0;
      if (quantity <= 0) continue;
      neededByProduct.update(
        line.product,
        (existing) => existing + quantity,
        ifAbsent: () => quantity,
      );
    }

    final shortages = <String>[];
    for (final entry in neededByProduct.entries) {
      final item = stockItems
          .where((i) => i.productType == entry.key)
          .firstOrNull;
      if (item == null) continue;
      if (item.quantityOnHand < entry.value) {
        shortages.add(
          '${item.displayName}: need ${entry.value} bags, '
          'only ${item.quantityOnHand} available',
        );
      }
    }
    return shortages;
  }

  void _onPaymentMethodChanged(PaymentMethod method) {
    setState(() {
      _paymentMethod = method;
      if (method == PaymentMethod.credit) {
        _amountPaidController.text = '0';
      } else if (method != PaymentMethod.part) {
        _amountPaidController.text = NumberFormat.decimalPattern(
          'en_NG',
        ).format(_total);
      }
    });
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_customerType == CustomerType.distributor && _distributorName == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Select a distributor.')));
      return;
    }
    if (_amountPaid > _total) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Amount paid cannot be more than the total.'),
        ),
      );
      return;
    }

    final user = ref.read(authStateProvider);
    final sale = Sale(
      id: 'sale-${DateTime.now().microsecondsSinceEpoch}',
      dateTime: DateTime.now(),
      customerType: _customerType,
      customerName: _customerType == CustomerType.distributor
          ? _distributorName
          : null,
      lines: [
        for (final line in _lines)
          SaleLine(
            product: line.product,
            quantity: int.parse(line.quantityController.text),
            unitPrice: parseNairaText(line.unitPriceController.text),
          ),
      ],
      total: _total,
      amountPaid: _amountPaid,
      paymentMethod: _paymentMethod,
      balance: _balance,
      recordedBy: user?.fullName ?? 'Unknown',
    );

    final saved = await ref
        .read(recordSaleControllerProvider.notifier)
        .record(
          sale,
          paidChannel: _paymentMethod == PaymentMethod.part
              ? _paidChannel
              : null,
        );
    if (!mounted) return;

    if (saved == null) {
      final error = ref.read(recordSaleControllerProvider).error;
      final reason = readableErrorMessage(error);
      showActionErrorSnackBar(context, message: reason);
      return;
    }

    // This screen is shown as a modal (see SalesListScreen) — pop with
    // the saved sale instead of navigating to the receipt directly, so
    // the caller (which outlives this modal) can open it as its own
    // modal once this one has actually closed.
    Navigator.of(context).pop(saved);
  }

  @override
  Widget build(BuildContext context) {
    final isSaving = ref.watch(recordSaleControllerProvider).isLoading;
    final shortages = _stockShortages(ref);

    return Scaffold(
      appBar: AppBar(title: const Text('Record sale')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Form(
            key: _formKey,
            child: ListView(
              children: [
                // Wider than the usual 680 form cap — the tablet/desktop
                // product table needs the room a single-column form
                // doesn't.
                ResponsiveCenter(
                  maxWidth: 900,
                  child: Column(
                    children: [
                      SaleCustomerSection(
                        customerType: _customerType,
                        distributorName: _distributorName,
                        onCustomerTypeChanged: (type) => setState(() {
                          _customerType = type;
                          if (type == CustomerType.walkIn) {
                            _distributorName = null;
                          }
                        }),
                        onDistributorSelected: (name) =>
                            setState(() => _distributorName = name),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      SaleLinesSection(
                        lines: _lines,
                        onProductChanged: _onLineProductChanged,
                        onRemove: _removeLine,
                        onAddLine: _addLine,
                      ),
                      if (shortages.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.md),
                        AppInlineAlert(
                          severity: AppAlertSeverity.error,
                          message:
                              'Not enough stock to record this sale:\n'
                              '${shortages.join('\n')}',
                        ),
                      ],
                      const SizedBox(height: AppSpacing.xl),
                      AppStat(label: 'Total', value: formatNaira(_total)),
                      const SizedBox(height: AppSpacing.xl),
                      SalePaymentSection(
                        paymentMethod: _paymentMethod,
                        amountPaidController: _amountPaidController,
                        balance: _balance,
                        customerLabel: _customerLabel,
                        onMethodChanged: _onPaymentMethodChanged,
                        paidChannel: _paidChannel,
                        onPaidChannelChanged: (channel) =>
                            setState(() => _paidChannel = channel),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      AppButton(
                        label: 'Record sale',
                        isLoading: isSaving,
                        expanded: true,
                        onPressed: (isSaving || shortages.isNotEmpty)
                            ? null
                            : _submit,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
