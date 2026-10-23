import 'dart:typed_data';

import '../models/barcode_enums.dart';

/// Normalizes a camera frame buffer when `rowStride` contains hardware row padding
/// (common on Android YUV420 `yPlane` and iOS/macOS CoreVideo `BGRA8888` buffers).
Uint8List normalizeRowStrideBuffer(
  Uint8List rawBytes, {
  required int width,
  required int height,
  required int rowStride,
  required PixelFormat format,
}) {
  final int tightRowBytes = width * format.bytesPerPixel;
  if (rowStride <= 0 || rowStride == tightRowBytes) {
    return rawBytes;
  }
  if (rowStride < tightRowBytes) {
    throw ArgumentError.value(
      rowStride,
      'rowStride',
      'rowStride ($rowStride) cannot be smaller than width * bytesPerPixel ($tightRowBytes).',
    );
  }
  final Uint8List compact = Uint8List(tightRowBytes * height);
  for (int row = 0; row < height; row++) {
    final int srcStart = row * rowStride;
    final int dstStart = row * tightRowBytes;
    if (srcStart + tightRowBytes <= rawBytes.length) {
      compact.setRange(dstStart, dstStart + tightRowBytes, rawBytes, srcStart);
    }
  }
  return compact;
}
