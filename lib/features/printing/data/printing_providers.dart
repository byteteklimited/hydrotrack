import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'thermal_printer_driver.dart';

final thermalPrinterDriverProvider = Provider<ThermalPrinterDriver>(
  (ref) => ThermalPrinterDriver(),
);
