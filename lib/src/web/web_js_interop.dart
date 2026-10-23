// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import '../models/barcode_enums.dart';

@JS('document')
external JSObject get jsDocument;

@JS('navigator')
external JSObject get jsNavigator;

@JS('window')
external JSObject get jsWindow;

/// Creates a DOM element via `document.createElement(tagName)`.
JSObject createDomElement(String tagName) =>
    jsDocument.callMethod<JSObject>('createElement'.toJS, tagName.toJS);

/// Converts any [PixelFormat] buffer into a tightly packed `RGBA8888` byte array.
Uint8List convertToTightRgba(
  Uint8List bytes, {
  required int width,
  required int height,
  required int rowStride,
  required PixelFormat format,
}) {
  final int bpp = format.bytesPerPixel;
  final int stride = rowStride > 0 ? rowStride : (width * bpp);
  if (format == PixelFormat.rgba8888 && stride == width * 4) {
    return bytes;
  }
  final Uint8List out = Uint8List(width * height * 4);
  for (int y = 0; y < height; y++) {
    for (int x = 0; x < width; x++) {
      final int srcIdx = y * stride + x * bpp;
      final int dstIdx = (y * width + x) * 4;
      if (srcIdx + bpp > bytes.length) continue;
      switch (format) {
        case PixelFormat.lum:
          final int lum = bytes[srcIdx];
          out[dstIdx] = lum;
          out[dstIdx + 1] = lum;
          out[dstIdx + 2] = lum;
          out[dstIdx + 3] = 255;
          break;
        case PixelFormat.rgba8888:
          out[dstIdx] = bytes[srcIdx];
          out[dstIdx + 1] = bytes[srcIdx + 1];
          out[dstIdx + 2] = bytes[srcIdx + 2];
          out[dstIdx + 3] = bytes[srcIdx + 3];
          break;
        case PixelFormat.bgra8888:
          out[dstIdx] = bytes[srcIdx + 2];
          out[dstIdx + 1] = bytes[srcIdx + 1];
          out[dstIdx + 2] = bytes[srcIdx];
          out[dstIdx + 3] = bytes[srcIdx + 3];
          break;
        case PixelFormat.rgb888:
          out[dstIdx] = bytes[srcIdx];
          out[dstIdx + 1] = bytes[srcIdx + 1];
          out[dstIdx + 2] = bytes[srcIdx + 2];
          out[dstIdx + 3] = 255;
          break;
      }
    }
  }
  return out;
}
