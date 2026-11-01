import 'dart:typed_data';

/// The top of a receipt or report: logo, business name and the profile
/// lines (address, contacts, registration numbers).
class BusinessHeader {
  const BusinessHeader({required this.name, this.lines = const [], this.logo});

  final String name;
  final List<String> lines;
  final Uint8List? logo;
}
