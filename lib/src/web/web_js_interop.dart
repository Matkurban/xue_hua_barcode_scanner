// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:math' as math;
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

/// Applies a 3x3 minimum-luminance morphological filter to connect circular
/// dot-matrix QR code modules on Web.
Uint8List dilateDarkDotsRgba3x3(
  Uint8List rgbaBytes, {
  required int width,
  required int height,
}) {
  final Uint8List lum = Uint8List(width * height);
  for (int i = 0, p = 0; i < lum.length; i++, p += 4) {
    lum[i] =
        ((306 * rgbaBytes[p] +
                    601 * rgbaBytes[p + 1] +
                    117 * rgbaBytes[p + 2] +
                    512) >>
                10)
            .clamp(0, 255);
  }

  final Uint8List temp = Uint8List(width * height);
  for (int y = 0; y < height; y++) {
    final int rowOffset = y * width;
    for (int x = 0; x < width; x++) {
      int m = lum[rowOffset + x];
      if (x > 0) m = math.min(m, lum[rowOffset + x - 1]);
      if (x + 1 < width) m = math.min(m, lum[rowOffset + x + 1]);
      temp[rowOffset + x] = m;
    }
  }

  final Uint8List outRgba = Uint8List(width * height * 4);
  for (int y = 0; y < height; y++) {
    final int r0 = math.max(0, y - 1) * width;
    final int r1 = y * width;
    final int r2 = math.min(height - 1, y + 1) * width;
    for (int x = 0; x < width; x++) {
      final int m = math.min(
        temp[r0 + x],
        math.min(temp[r1 + x], temp[r2 + x]),
      );
      final int dst = (r1 + x) * 4;
      outRgba[dst] = m;
      outRgba[dst + 1] = m;
      outRgba[dst + 2] = m;
      outRgba[dst + 3] = 255;
    }
  }
  return outRgba;
}
