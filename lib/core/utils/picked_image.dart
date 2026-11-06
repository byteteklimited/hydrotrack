import 'dart:typed_data';

/// An image someone chose from their device.
class PickedImage {
  const PickedImage({required this.bytes, required this.extension});

  final Uint8List bytes;

  /// Lower case, without the dot: "png", "jpg".
  final String extension;
}

/// The chosen image could not be used; [message] says why and what to do.
class ImagePickException implements Exception {
  const ImagePickException(this.message);

  final String message;

  @override
  String toString() => message;
}
