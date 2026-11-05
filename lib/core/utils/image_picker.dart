import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

import 'picker_web_options.dart';

/// An image someone chose from their device.
class PickedImage {
  const PickedImage({required this.bytes, required this.extension});

  final Uint8List bytes;

  /// Lower case, without the dot: "png", "jpg".
  final String extension;
}

/// Opens the device's photo/file picker for one image. Null when the
/// person closes it without choosing. Asks for "any image" rather than a
/// list of extensions: iPhones only offer the photo library (and convert
/// HEIC photos to JPEG) for that.
Future<PickedImage?> pickImage() async {
  final picked = await FilePicker.pickFiles(
    type: FileType.image,
    webOptions: pickerWebOptions,
  );
  final file = picked.firstOrNull;
  if (file == null) return null;
  return PickedImage(
    bytes: await file.readAsBytes(),
    extension: (file.extension ?? '').replaceFirst('.', '').toLowerCase(),
  );
}
