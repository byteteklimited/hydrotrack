import 'dart:async';
import 'dart:js_interop';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

import 'picked_image.dart';

/// Longest side of the image we keep. Plenty for a logo on screen, receipts
/// and PDFs, and keeps the upload small.
const _maxSide = 1024;

/// Browsers: a plain file input, read and redrawn here as a PNG. Redrawing
/// in the browser means any photo the browser can show works (HEIC on
/// iPhones, large camera photos, WebP, GIF), always arrives as a small PNG,
/// and keeps its right way up.
Future<PickedImage?> pickImage() async {
  final file = await _chooseFile();
  if (file == null) return null;
  return PickedImage(bytes: await _toPng(file), extension: 'png');
}

/// Opens the browser's picker. Null when the person cancels.
Future<web.File?> _chooseFile() async {
  final chosen = Completer<web.File?>();
  final input = web.HTMLInputElement()
    ..type = 'file'
    ..accept = 'image/*'
    ..style.display = 'none';
  void finish(web.File? file) {
    if (!chosen.isCompleted) chosen.complete(file);
  }

  input
    ..addEventListener(
      'change',
      ((web.Event _) {
        final files = input.files;
        finish(files != null && files.length > 0 ? files.item(0) : null);
      }).toJS,
    )
    ..addEventListener('cancel', ((web.Event _) => finish(null)).toJS);
  // Safari only reports the choice for an input that is on the page.
  web.document.body!.append(input);
  input.click();
  try {
    return await chosen.future;
  } finally {
    input.remove();
  }
}

Future<Uint8List> _toPng(web.File file) async {
  final web.ImageBitmap bitmap;
  try {
    // Read the bytes first: a photo the browser is not allowed to read
    // (Photos library, iCloud-only) fails here, not when drawing.
    final bytes = await file.arrayBuffer().toDart;
    bitmap = await web.window
        .createImageBitmap(
          web.Blob([bytes].toJS, web.BlobPropertyBag(type: file.type)),
        )
        .toDart;
  } catch (error) {
    debugPrint('Image read failed for "${file.name}" (${file.type}): $error');
    throw ImagePickException(_cannotOpen(file));
  }
  try {
    final scale = math.min(
      1.0,
      _maxSide / math.max(bitmap.width, bitmap.height),
    );
    final width = math.max(1, (bitmap.width * scale).round());
    final height = math.max(1, (bitmap.height * scale).round());
    final canvas = web.HTMLCanvasElement()
      ..width = width
      ..height = height;
    final context = canvas.getContext('2d')! as web.CanvasRenderingContext2D
      ..imageSmoothingQuality = 'high';
    context.drawImage(bitmap, 0, 0, width, height);
    final png = Completer<web.Blob?>();
    canvas.toBlob(((web.Blob? blob) => png.complete(blob)).toJS, 'image/png');
    final blob = await png.future;
    if (blob == null) throw StateError('The browser made no PNG');
    return (await blob.arrayBuffer().toDart).toDart.asUint8List();
  } catch (error) {
    debugPrint('Image redraw failed for "${file.name}": $error');
    throw const ImagePickException(
      'Could not prepare that image. Try a smaller PNG or JPG.',
    );
  } finally {
    bitmap.close();
  }
}

/// What to say when the browser could not open the chosen file.
String _cannotOpen(web.File file) {
  final name = file.name.toLowerCase();
  if (name.endsWith('.heic') || name.endsWith('.heif')) {
    return 'This browser cannot open HEIC photos. Choose a PNG or JPG, or '
        'open this photo and export it as JPG first.';
  }
  return 'Could not read "${file.name}". If it is in your Photos app or '
      'iCloud, save a copy to Desktop or Downloads first and choose it from '
      'there. Otherwise choose a PNG or JPG image.';
}
