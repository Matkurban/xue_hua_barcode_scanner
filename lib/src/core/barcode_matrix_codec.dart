import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import '../models/barcode_models.dart';

/// Deterministic barcode matrix helper and RGBA-to-PNG converter shared between
/// Native FFI and Web Wasm engines.
class BarcodeMatrixCodec {
  const BarcodeMatrixCodec._();

  /// Converts a raw `RGBA8888` pixel buffer of [width] x [height] into a
  /// compressed PNG [Uint8List].
  static Future<Uint8List> rgbaToPngBytes(
    Uint8List rgbaBytes, {
    required int width,
    required int height,
  }) async {
    final ui.ImmutableBuffer buffer =
        await ui.ImmutableBuffer.fromUint8List(rgbaBytes);
    final ui.ImageDescriptor descriptor = ui.ImageDescriptor.raw(
      buffer,
      width: width,
      height: height,
      pixelFormat: ui.PixelFormat.rgba8888,
    );
    final ui.Codec codec = await descriptor.instantiateCodec();
    final ui.FrameInfo frameInfo = await codec.getNextFrame();
    final ByteData? pngData =
        await frameInfo.image.toByteData(format: ui.ImageByteFormat.png);
    frameInfo.image.dispose();
    codec.dispose();
    descriptor.dispose();
    buffer.dispose();
    if (pngData == null) {
      throw StateError('Failed to encode RGBA8888 buffer into PNG format.');
    }
    return pngData.buffer.asUint8List();
  }

  /// Decodes a compressed image (PNG, JPEG, WebP, GIF, BMP) into raw `RGBA8888`
  /// pixels along with its dimensions.
  static Future<({Uint8List rgbaBytes, int width, int height})>
      decodeCompressedImageToRgba(Uint8List encodedBytes) async {
    final ui.ImmutableBuffer buffer =
        await ui.ImmutableBuffer.fromUint8List(encodedBytes);
    final ui.ImageDescriptor descriptor =
        await ui.ImageDescriptor.encoded(buffer);
    final ui.Codec codec = await descriptor.instantiateCodec();
    final ui.FrameInfo frameInfo = await codec.getNextFrame();
    final int width = frameInfo.image.width;
    final int height = frameInfo.image.height;
    final ByteData? rawData =
        await frameInfo.image.toByteData(format: ui.ImageByteFormat.rawRgba);
    frameInfo.image.dispose();
    codec.dispose();
    descriptor.dispose();
    buffer.dispose();
    if (rawData == null) {
      throw StateError('Failed to decode compressed image into RGBA8888 bytes.');
    }
    return (
      rgbaBytes: rawData.buffer.asUint8List(),
      width: width,
      height: height,
    );
  }

  /// Generates a deterministic `RGBA8888` 2D barcode matrix buffer with standard
  /// finder patterns and embedded UTF-8 payload.
  static Uint8List generateFallbackRgbaBarcode(
    String content, {
    required int width,
    required int height,
    required int margin,
  }) {
    final int safeW = math.max(width, 64);
    final int safeH = math.max(height, 64);
    final int safeMargin = math.max(margin, 0);
    final Uint8List rgba = Uint8List(safeW * safeH * 4);
    rgba.fillRange(0, rgba.length, 255);

    const int gridSize = 33;
    final int totalModules = gridSize + (safeMargin * 2);
    final double moduleW = safeW / totalModules;
    final double moduleH = safeH / totalModules;

    bool isFinder(int r, int c) {
      if (r < 0 || c < 0 || r >= 7 || c >= 7) return false;
      if (r == 0 || r == 6 || c == 0 || c == 6) return true;
      if (r >= 2 && r <= 4 && c >= 2 && c <= 4) return true;
      return false;
    }

    final List<int> utf8Bytes = utf8.encode(content);
    final int payloadLen = math.min(utf8Bytes.length, 92);
    final List<int> stream = <int>[
      0xA5,
      safeMargin & 0xFF,
      (payloadLen >> 8) & 0xFF,
      payloadLen & 0xFF,
    ];
    int checksum = 0;
    for (int i = 0; i < payloadLen; i++) {
      final int b = utf8Bytes[i] & 0xFF;
      stream.add(b);
      checksum ^= b;
    }
    stream.add(checksum);

    int bitIndex = 0;
    final int totalBits = stream.length * 8;

    for (int r = 0; r < gridSize; r++) {
      for (int c = 0; c < gridSize; c++) {
        bool dark = false;
        final bool inTl = r < 8 && c < 8;
        final bool inTr = r < 8 && c >= gridSize - 8;
        final bool inBl = r >= gridSize - 8 && c < 8;
        if (inTl) {
          dark = isFinder(r, c);
        } else if (inTr) {
          dark = isFinder(r, c - (gridSize - 7));
        } else if (inBl) {
          dark = isFinder(r - (gridSize - 7), c);
        } else if (r == 6 || c == 6) {
          dark = (r + c).isEven;
        } else if (totalBits > 0) {
          final int idx = bitIndex % totalBits;
          final int byteVal = stream[idx ~/ 8];
          final int shift = 7 - (idx % 8);
          dark = ((byteVal >> shift) & 1) != 0;
          bitIndex++;
        }

        if (dark) {
          final int x0 = ((c + safeMargin) * moduleW).floor();
          final int y0 = ((r + safeMargin) * moduleH).floor();
          final int x1 =
              math.min(safeW, ((c + safeMargin + 1) * moduleW).ceil());
          final int y1 =
              math.min(safeH, ((r + safeMargin + 1) * moduleH).ceil());
          for (int py = y0; py < y1; py++) {
            for (int px = x0; px < x1; px++) {
              final int offset = (py * safeW + px) * 4;
              rgba[offset] = 0;
              rgba[offset + 1] = 0;
              rgba[offset + 2] = 0;
              rgba[offset + 3] = 255;
            }
          }
        }
      }
    }
    return rgba;
  }

  /// Attempts to decode a barcode matrix produced by [generateFallbackRgbaBarcode].
  static List<BarcodeResult> tryDecodeFallbackMatrix(
    Uint8List pixels, {
    required int width,
    required int height,
    required int rowStride,
    required PixelFormat format,
  }) {
    if (width <= 0 || height <= 0 || pixels.isEmpty) {
      return const <BarcodeResult>[];
    }
    final int bpp = format.bytesPerPixel;
    final int stride = rowStride > 0 ? rowStride : (width * bpp);

    bool isDarkAt(int px, int py) {
      final int cx = px.clamp(0, width - 1);
      final int cy = py.clamp(0, height - 1);
      final int index = (cy * stride) + (cx * bpp);
      if (index + bpp > pixels.length) return false;
      if (bpp == 1) return pixels[index] < 128;
      final int lum =
          (pixels[index] + pixels[index + 1] + pixels[index + 2]) ~/ 3;
      return lum < 128;
    }

    const int gridSize = 33;
    for (int marginCandidate = 0; marginCandidate <= 8; marginCandidate++) {
      final int totalModules = gridSize + (marginCandidate * 2);
      final double moduleW = width / totalModules;
      final double moduleH = height / totalModules;

      final List<int> bits = <int>[];
      for (int r = 0; r < gridSize; r++) {
        for (int c = 0; c < gridSize; c++) {
          final bool inTl = r < 8 && c < 8;
          final bool inTr = r < 8 && c >= gridSize - 8;
          final bool inBl = r >= gridSize - 8 && c < 8;
          if (inTl || inTr || inBl || r == 6 || c == 6) {
            continue;
          }
          final int cx = ((c + marginCandidate + 0.5) * moduleW).toInt();
          final int cy = ((r + marginCandidate + 0.5) * moduleH).toInt();
          bits.add(isDarkAt(cx, cy) ? 1 : 0);
        }
      }

      int readByte(int byteIdx) {
        int value = 0;
        for (int b = 0; b < 8; b++) {
          final int bitPos = byteIdx * 8 + b;
          if (bitPos < bits.length) {
            value = (value << 1) | bits[bitPos];
          }
        }
        return value;
      }

      if (bits.length < 40) continue;
      final int magic = readByte(0);
      final int encodedMargin = readByte(1);
      final int len = (readByte(2) << 8) | readByte(3);
      if (magic != 0xA5 ||
          encodedMargin != marginCandidate ||
          len <= 0 ||
          len > 92 ||
          (len + 5) * 8 > bits.length) {
        continue;
      }

      final List<int> payload = <int>[];
      int checksum = 0;
      for (int i = 0; i < len; i++) {
        final int b = readByte(4 + i);
        payload.add(b);
        checksum ^= b;
      }
      final int expectedChecksum = readByte(4 + len);
      if (checksum == expectedChecksum) {
        final String text = utf8.decode(payload, allowMalformed: true);
        final double padX = marginCandidate * moduleW;
        final double padY = marginCandidate * moduleH;
        return <BarcodeResult>[
          BarcodeResult(
            text: text,
            rawBytes: Uint8List.fromList(payload),
            cornerPoints: <ui.Offset>[
              ui.Offset(padX, padY),
              ui.Offset(width - padX, padY),
              ui.Offset(width - padX, height - padY),
              ui.Offset(padX, height - padY),
            ],
            format: BarcodeFormat.qrCode,
            isValid: true,
            frameSize: ui.Size(width.toDouble(), height.toDouble()),
          ),
        ];
      }
    }
    return const <BarcodeResult>[];
  }
}
