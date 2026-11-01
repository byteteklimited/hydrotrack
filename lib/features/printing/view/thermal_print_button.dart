import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/action_error.dart';
import '../../../core/widgets/app_button.dart';
import '../../organizations/data/providers/organization_providers.dart';
import '../../sales/data/models/sale.dart';
import '../data/escpos_receipt.dart';
import '../data/printer_device.dart';
import '../data/printing_providers.dart';
import '../data/receipt_printer_settings.dart';
import 'printer_setup_sheet.dart';

/// Android: prints [sale] straight to the phone's Bluetooth receipt
/// printer (choosing one the first time), plus "Change printer". Nothing
/// on devices that can't.
class ThermalPrintButton extends ConsumerStatefulWidget {
  const ThermalPrintButton({super.key, required this.sale});

  final Sale sale;

  @override
  ConsumerState<ThermalPrintButton> createState() => _ThermalPrintButtonState();
}

class _ThermalPrintButtonState extends ConsumerState<ThermalPrintButton> {
  bool _printing = false;

  Future<ReceiptPrinterSettings?> _setUp(ReceiptPrinterSettings current) =>
      showPrinterSetup(context, current);

  Future<void> _print() async {
    setState(() => _printing = true);
    try {
      var settings = await ReceiptPrinterSettings.load();
      if (settings.printer == null) {
        if (!mounted) return;
        final chosen = await _setUp(settings);
        if (chosen?.printer == null) return;
        settings = chosen!;
      }
      final bytes = await buildEscPosReceipt(
        widget.sale,
        header: await ref.read(businessHeaderProvider.future),
        paper: settings.paper,
      );
      await ref
          .read(thermalPrinterDriverProvider)
          .printBytes(settings.printer!.address, bytes);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Printed on ${settings.printer!.name}.')),
        );
      }
    } on PrinterException catch (error) {
      if (mounted) showActionErrorSnackBar(context, message: error.message);
    } catch (error) {
      if (mounted) {
        showActionErrorSnackBar(
          context,
          message: readableErrorMessage(error) ?? "Couldn't print. Try again.",
        );
      }
    } finally {
      if (mounted) setState(() => _printing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!ref.watch(thermalPrinterDriverProvider).isSupported) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: Row(
        children: [
          Expanded(
            child: AppButton(
              label: 'Print receipt',
              leadingIcon: Icons.receipt_long_outlined,
              isLoading: _printing,
              onPressed: _printing ? null : _print,
            ),
          ),
          AppButton(
            label: 'Change printer',
            variant: AppButtonVariant.text,
            onPressed: () async => _setUp(await ReceiptPrinterSettings.load()),
          ),
        ],
      ),
    );
  }
}
