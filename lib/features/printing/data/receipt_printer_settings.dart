import 'package:shared_preferences/shared_preferences.dart';

import 'printer_device.dart';

/// Receipt paper widths the common printers use.
enum PaperWidth {
  mm58('58 mm', 32),
  mm80('80 mm', 48);

  const PaperWidth(this.label, this.charactersPerLine);

  final String label;

  /// Characters per line in the printer's normal font.
  final int charactersPerLine;
}

/// The receipt printer chosen on this device (each phone has its own).
class ReceiptPrinterSettings {
  const ReceiptPrinterSettings({this.printer, this.paper = PaperWidth.mm58});

  final PrinterDevice? printer;
  final PaperWidth paper;

  static const _addressKey = 'receipt_printer_address';
  static const _nameKey = 'receipt_printer_name';
  static const _paperKey = 'receipt_printer_paper';

  static Future<ReceiptPrinterSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final address = prefs.getString(_addressKey);
    return ReceiptPrinterSettings(
      printer: address == null
          ? null
          : PrinterDevice(
              name: prefs.getString(_nameKey) ?? 'Printer',
              address: address,
            ),
      paper:
          PaperWidth.values.asNameMap()[prefs.getString(_paperKey)] ??
          PaperWidth.mm58,
    );
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    if (printer == null) {
      await prefs.remove(_addressKey);
      await prefs.remove(_nameKey);
    } else {
      await prefs.setString(_addressKey, printer!.address);
      await prefs.setString(_nameKey, printer!.name);
    }
    await prefs.setString(_paperKey, paper.name);
  }
}
