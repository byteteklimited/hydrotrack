import 'dart:io';

import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

import 'printer_device.dart';

/// Bluetooth ESC/POS receipt printers, from the Android app (the common
/// 58 mm / 80 mm printers, paired once in the phone's Bluetooth settings).
class ThermalPrinterDriver {
  bool get isSupported => Platform.isAndroid;

  Future<List<PrinterDevice>> pairedPrinters() async {
    await _ready();
    final paired = await PrintBluetoothThermal.pairedBluetooths;
    return [
      for (final device in paired)
        PrinterDevice(name: device.name, address: device.macAdress),
    ];
  }

  Future<void> printBytes(String address, List<int> bytes) async {
    await _ready();
    if (!await PrintBluetoothThermal.connectionStatus) {
      final connected = await PrintBluetoothThermal.connect(
        macPrinterAddress: address,
      );
      if (!connected) {
        throw const PrinterException(
          "Couldn't connect to the printer. Check it's on and nearby.",
        );
      }
    }
    if (!await PrintBluetoothThermal.writeBytes(bytes)) {
      throw const PrinterException(
        'The printer didn\'t accept the receipt. Check its paper and try again.',
      );
    }
  }

  Future<void> _ready() async {
    if (!isSupported) {
      throw const PrinterException(
        'Bluetooth printing works in the Android app.',
      );
    }
    if (!await PrintBluetoothThermal.isPermissionBluetoothGranted) {
      throw const PrinterException(
        'Allow HydroTrack to use "Nearby devices" (Bluetooth) in the phone\'s '
        'app settings, then try again.',
      );
    }
    if (!await PrintBluetoothThermal.bluetoothEnabled) {
      throw const PrinterException('Turn on Bluetooth, then try again.');
    }
  }
}
