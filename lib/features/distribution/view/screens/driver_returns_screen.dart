import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/distribution_rates.dart';
import '../../../../core/constants/payment_channel.dart';
import '../../../../core/theme/app_breakpoints.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/action_error.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/responsive_center.dart';
import '../../../sales/data/models/sale.dart';
import '../../../sales/view/widgets/sale_customer_section.dart';
import '../../data/models/load_out.dart';
import '../../data/providers/distribution_providers.dart';

num _parseNaira(String text) => num.tryParse(text.replaceAll(',', '')) ?? 0;

/// The reconciliation for one trip: sold + returned + damaged must equal
/// what was loaded before it can be settled. If any bags were sold, the
/// trip also records a real sale — walk-in at the standard per-bag rate
/// by default, or to a named distributor at its own price when one is
/// picked, same as "Record sale" elsewhere in the app.
class DriverReturnsScreen extends ConsumerStatefulWidget {
  const DriverReturnsScreen({super.key, required this.loadOut});

  final LoadOut loadOut;

  @override
  ConsumerState<DriverReturnsScreen> createState() =>
      _DriverReturnsScreenState();
}

class _DriverReturnsScreenState extends ConsumerState<DriverReturnsScreen> {
  final _soldController = TextEditingController();
  final _returnedController = TextEditingController();
  final _damagedController = TextEditingController();
  final _cashController = TextEditingController();
  final _noteController = TextEditingController();
  late final _unitPriceController = TextEditingController(
    text: DistributionRates.cashPerBag.toString(),
  );

  CustomerType _customerType = CustomerType.walkIn;
  String? _distributorName;

  @override
  void initState() {
    super.initState();
    for (final controller in [
      _soldController,
      _returnedController,
      _damagedController,
      _cashController,
      _unitPriceController,
    ]) {
      controller.addListener(_recompute);
    }
  }

  @override
  void dispose() {
    for (final controller in [
      _soldController,
      _returnedController,
      _damagedController,
      _cashController,
      _unitPriceController,
    ]) {
      controller.removeListener(_recompute);
      controller.dispose();
    }
    _noteController.dispose();
    super.dispose();
  }

  void _recompute() => setState(() {});

  int get _sold => int.tryParse(_soldController.text) ?? 0;
  int get _returned => int.tryParse(_returnedController.text) ?? 0;
  int get _damaged => int.tryParse(_damagedController.text) ?? 0;
  int get _accountedFor => _sold + _returned + _damaged;
  int get _difference => widget.loadOut.bagsLoaded - _accountedFor;
  bool get _balances => _difference == 0;

  bool get _isDistributorSale => _customerType == CustomerType.distributor;

  /// Walk-in trips use the flat standard rate, unchanged from before
  /// this screen could attribute a sale to a specific customer; a
  /// distributor sale uses its own price, same as "Record sale".
  num get _unitPrice => _isDistributorSale
      ? _parseNaira(_unitPriceController.text)
      : DistributionRates.cashPerBag;

  num get _expectedCash => _sold * _unitPrice;
  num get _cashReturned => _parseNaira(_cashController.text);
  num get _shortfall => _expectedCash - _cashReturned;

  Future<void> _submit() async {
    if (!_balances) return;
    if (_isDistributorSale && _distributorName == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Select a distributor.')));
      return;
    }

    // "Cash returned" is always physical cash the driver hands over —
    // this screen has no reason to ask which channel it came through.
    // A walk-in sale is always treated as fully paid: walk-ins can't
    // owe a debt, so any shortfall stays exactly what it already was
    // (a cash-accountability discrepancy, tracked by the note below),
    // not a balance on the sale itself.
    final saleTotal = _sold * _unitPrice;
    final amountPaid = _isDistributorSale
        ? (_cashReturned > saleTotal ? saleTotal : _cashReturned)
        : saleTotal;
    final paymentMethod = amountPaid >= saleTotal
        ? PaymentMethod.cash
        : amountPaid > 0
        ? PaymentMethod.part
        : PaymentMethod.credit;

    await ref
        .read(distributionActionControllerProvider.notifier)
        .settleTrip(
          loadOutId: widget.loadOut.id,
          bagsSold: _sold,
          bagsReturned: _returned,
          bagsDamaged: _damaged,
          cashReturned: _cashReturned,
          discrepancyNote: _noteController.text.trim().isEmpty
              ? null
              : _noteController.text.trim(),
          customerType: _customerType,
          customerName: _isDistributorSale ? _distributorName : null,
          unitPrice: _sold > 0 ? _unitPrice : null,
          amountPaid: amountPaid,
          paymentMethod: paymentMethod,
          paidChannel: paymentMethod == PaymentMethod.part
              ? PaymentChannel.cash
              : null,
        );
    if (!mounted) return;

    if (ref.read(distributionActionControllerProvider).hasError) {
      showActionErrorSnackBar(context);
      return;
    }

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSaving = ref.watch(distributionActionControllerProvider).isLoading;

    return Scaffold(
      appBar: AppBar(title: const Text('Driver returns')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: ListView(
            children: [
              ResponsiveCenter(
                maxWidth: 680,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bags loaded',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      '${widget.loadOut.bagsLoaded}',
                      style: theme.textTheme.headlineSmall,
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    _ReconciliationFields(
                      soldController: _soldController,
                      returnedController: _returnedController,
                      damagedController: _damagedController,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      _balances
                          ? 'Bags accounted for.'
                          : _difference > 0
                          ? '$_difference bags unaccounted for.'
                          : '${-_difference} bags more than what was loaded.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: _balances
                            ? theme.colorScheme.onSurfaceVariant
                            : AppColors.moneyOut,
                        fontWeight: _balances ? null : FontWeight.w600,
                      ),
                    ),
                    if (_sold > 0) ...[
                      const SizedBox(height: AppSpacing.xl),
                      Text(
                        'Who bought it?',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: AppSpacing.sm),
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
                      if (_isDistributorSale) ...[
                        const SizedBox(height: AppSpacing.md),
                        AppTextField.naira(
                          hint: 'e.g. 300',
                          label: 'Price per bag',
                          controller: _unitPriceController,
                        ),
                      ],
                    ],
                    const SizedBox(height: AppSpacing.xl),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: AppTextField.naira(
                            hint: 'e.g. 30,000',
                            label: 'Cash returned',
                            controller: _cashController,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Padding(
                          padding: const EdgeInsets.only(top: AppSpacing.lg),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'Expected',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              Text(
                                formatNaira(_expectedCash),
                                style: theme.textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (_isDistributorSale && _shortfall > 0) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        '${formatNaira(_shortfall)} will be added to '
                        "${_distributorName ?? 'the distributor'}'s balance.",
                        style: theme.textTheme.bodyMedium,
                      ),
                    ] else if (_shortfall > 0) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        '${formatNaira(_shortfall)} short of the ${formatNaira(_expectedCash)} expected.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppColors.moneyOut,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.md),
                    AppTextField(
                      hint: 'e.g. 2 bags burst on the road',
                      label: 'Note (optional)',
                      controller: _noteController,
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    AppButton(
                      label: 'Settle trip',
                      isLoading: isSaving,
                      expanded: true,
                      onPressed: (_balances && !isSaving) ? _submit : null,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Sold/returned/damaged must sum to what was loaded, so they read as
/// one reconciliation, not three unrelated fields — side by side from
/// the medium breakpoint up, stacked on phone same as before.
class _ReconciliationFields extends StatelessWidget {
  const _ReconciliationFields({
    required this.soldController,
    required this.returnedController,
    required this.damagedController,
  });

  final TextEditingController soldController;
  final TextEditingController returnedController;
  final TextEditingController damagedController;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final fields = [
          AppTextField.quantity(
            hint: 'e.g. 100',
            label: 'Bags sold',
            controller: soldController,
          ),
          AppTextField.quantity(
            hint: 'e.g. 10',
            label: 'Bags returned',
            controller: returnedController,
          ),
          AppTextField.quantity(
            hint: 'e.g. 2',
            label: 'Bags damaged',
            controller: damagedController,
          ),
        ];

        if (!AppBreakpoints.isMediumOrWider(constraints.maxWidth)) {
          return Column(
            children: [
              for (var i = 0; i < fields.length; i++) ...[
                fields[i],
                if (i != fields.length - 1)
                  const SizedBox(height: AppSpacing.md),
              ],
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < fields.length; i++) ...[
              Expanded(child: fields[i]),
              if (i != fields.length - 1) const SizedBox(width: AppSpacing.md),
            ],
          ],
        );
      },
    );
  }
}
