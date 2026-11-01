import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_dropdown_field.dart';
import '../data/printer_device.dart';
import '../data/printing_providers.dart';
import '../data/receipt_printer_settings.dart';

/// Choose this phone's receipt printer (from those paired in the phone's
/// Bluetooth settings) and its paper width. Returns the saved settings.
Future<ReceiptPrinterSettings?> showPrinterSetup(
  BuildContext context,
  ReceiptPrinterSettings current,
) {
  return showModalBottomSheet<ReceiptPrinterSettings>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _PrinterSetupSheet(current: current),
  );
}

class _PrinterSetupSheet extends ConsumerStatefulWidget {
  const _PrinterSetupSheet({required this.current});

  final ReceiptPrinterSettings current;

  @override
  ConsumerState<_PrinterSetupSheet> createState() => _PrinterSetupSheetState();
}

class _PrinterSetupSheetState extends ConsumerState<_PrinterSetupSheet> {
  late PrinterDevice? _printer = widget.current.printer;
  late PaperWidth _paper = widget.current.paper;
  late final Future<List<PrinterDevice>> _paired = ref
      .read(thermalPrinterDriverProvider)
      .pairedPrinters();

  Future<void> _save() async {
    final settings = ReceiptPrinterSettings(printer: _printer, paper: _paper);
    await settings.save();
    if (mounted) Navigator.of(context).pop(settings);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Receipt printer', style: theme.textTheme.titleLarge),
          const SizedBox(height: AppSpacing.xs),
          Text(
            "Pair the printer in the phone's Bluetooth settings first (its "
            'PIN is often 0000 or 1234), then choose it here.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          FutureBuilder<List<PrinterDevice>>(
            future: _paired,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Text(
                  '${snapshot.error}',
                  style: TextStyle(color: theme.colorScheme.error),
                );
              }
              if (!snapshot.hasData) return const LinearProgressIndicator();
              final printers = snapshot.data!;
              if (printers.isEmpty) {
                return const Text(
                  'No paired Bluetooth devices. Pair the printer, then open '
                  'this again.',
                );
              }
              return AppDropdownField<PrinterDevice?>(
                label: 'Printer',
                value: printers.contains(_printer) ? _printer : null,
                items: [null, ...printers],
                itemLabel: (p) => p?.name ?? 'Choose a printer',
                onChanged: (p) => setState(() => _printer = p),
              );
            },
          ),
          const SizedBox(height: AppSpacing.md),
          AppDropdownField<PaperWidth>(
            label: 'Paper width',
            value: _paper,
            items: PaperWidth.values,
            itemLabel: (w) => w.label,
            onChanged: (w) => setState(() => _paper = w!),
          ),
          const SizedBox(height: AppSpacing.xl),
          AppButton(
            label: 'Use this printer',
            expanded: true,
            onPressed: _printer == null ? null : _save,
          ),
        ],
      ),
    );
  }
}
