/// `pickImage()`: opens the device's photo/file picker for one image and
/// returns it, or null when the person closes the picker without choosing.
/// Throws [ImagePickException] when the chosen image cannot be used.
library;

export 'image_picker_io.dart'
    if (dart.library.js_interop) 'image_picker_web.dart';
export 'picked_image.dart';
