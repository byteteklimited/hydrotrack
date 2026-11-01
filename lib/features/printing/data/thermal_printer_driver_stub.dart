import 'printer_device.dart';

/// Browsers can't talk to Bluetooth receipt printers; use Print/Share.
class ThermalPrinterDriver {
  bool get isSupported => false;

  Future<List<PrinterDevice>> pairedPrinters() async => const [];

  Future<void> printBytes(String address, List<int> bytes) async {
    throw const PrinterException(
      'Bluetooth printing works in the Android app. Use Print or Share here.',
    );
  }
}
