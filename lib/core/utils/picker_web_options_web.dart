import 'package:file_picker/file_picker.dart';
import 'package:file_picker_web/file_picker_web.dart';

/// Browsers: wait for the browser to hand over the chosen file. By default
/// the picker gives up half a second after the page regains focus, which
/// on iPhones comes before the photo arrives, so nothing was uploaded.
const WebOptions pickerWebOptions = FilePickerWebOptions(
  cancelUploadOnWindowBlur: false,
);
