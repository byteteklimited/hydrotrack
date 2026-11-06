import 'package:file_picker/file_picker.dart';

import 'picked_image.dart';

/// Phones and desktop apps: the system picker. Asks for "any image" rather
/// than a list of extensions: iPhones only offer the photo library (and
/// convert HEIC photos to JPEG) for that.
Future<PickedImage?> pickImage() async {
  final picked = await FilePicker.pickFiles(type: FileType.image);
  final file = picked.firstOrNull;
  if (file == null) return null;
  try {
    return PickedImage(
      bytes: await file.readAsBytes(),
      extension: (file.extension ?? '').replaceFirst('.', '').toLowerCase(),
    );
  } catch (_) {
    throw const ImagePickException(
      'Could not read that image. Choose another one, or save a copy to '
      'your phone first and choose that.',
    );
  }
}
