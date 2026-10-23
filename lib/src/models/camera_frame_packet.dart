import 'dart:typed_data';

import 'barcode_enums.dart';

/// Raw camera frame packet delivered from platform camera streams to the FFI/Wasm decoder.
class CameraFramePacket {
  /// Creates a [CameraFramePacket].
  const CameraFramePacket({
    required this.bytes,
    required this.width,
    required this.height,
    this.rowStride = 0,
    this.format = PixelFormat.lum,
    this.sensorOrientation = 0,
  });

  /// Raw pixel buffer (e.g. Y-plane of YUV420/NV21, BGRA8888, or RGBA8888).
  final Uint8List bytes;

  /// Frame width in pixels.
  final int width;

  /// Frame height in pixels.
  final int height;

  /// Row byte stride (0 if tightly packed).
  final int rowStride;

  /// Pixel layout of [bytes].
  final PixelFormat format;

  /// Camera sensor clockwise orientation in degrees (`0`, `90`, `180`, `270`).
  final int sensorOrientation;
}
