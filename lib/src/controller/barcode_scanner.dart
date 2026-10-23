import 'dart:typed_data';

import '../core/scanner_engine_interface.dart';
import '../core/scanner_engine_selector.dart';
import '../models/barcode_enums.dart';
import '../models/barcode_result.dart';

/// High-level static/singleton API for `xue_hua_barcode_scanner`.
///
/// Provides unified 6-platform (Android, iOS, macOS, Windows, Linux, Web)
/// Barcode & 2D Code decoding and generation powered by `zxing-cpp` FFI and
/// `zxing-wasm` (`dart:js_interop`).
class XueHuaBarcodeScanner {
  XueHuaBarcodeScanner._();

  /// Shared singleton instance.
  static final XueHuaBarcodeScanner instance = XueHuaBarcodeScanner._();

  static final XueHuaScannerPlatformEngine _engine =
      createPlatformScannerEngine();

  /// Underlying platform engine (FFI on 5 native platforms, JS/Wasm on Web).
  static XueHuaScannerPlatformEngine get engine => _engine;

  /// Returns the active engine version string (e.g. `"zxing-cpp 3.1.1 (C++20 FFI)"`).
  static String get engineVersion => _engine.engineVersion;

  /// Decodes one or more barcodes from raw pixel bytes.
  ///
  /// - [rawPixelBytes]: Raw pixel buffer (`PixelFormat.lum` / YUV420 Y-plane,
  ///   `PixelFormat.rgba8888`, `PixelFormat.bgra8888`, or `PixelFormat.rgb888`).
  /// - [width]: Image width in pixels.
  /// - [height]: Image height in pixels.
  /// - [rowStride]: Bytes per row (pass `0` for tightly packed rows, or the
  ///   camera plane's `bytesPerRow` to handle hardware alignment padding).
  /// - [format]: Pixel layout of [rawPixelBytes].
  /// - [tryHarder]: Spend more CPU cycles finding rotated/warped symbols.
  /// - [tryRotate]: Check 90/180/270 degree orientations.
  /// - [tryInvert]: Check inverted (light-on-dark) barcodes.
  static Future<List<BarcodeResult>> decodeImageBytes(
    Uint8List rawPixelBytes, {
    required int width,
    required int height,
    int rowStride = 0,
    PixelFormat format = PixelFormat.rgba8888,
    bool tryHarder = true,
    bool tryRotate = true,
    bool tryInvert = true,
  }) {
    return _engine.decodeImageBytes(
      rawPixelBytes,
      width: width,
      height: height,
      rowStride: rowStride,
      format: format,
      tryHarder: tryHarder,
      tryRotate: tryRotate,
      tryInvert: tryInvert,
    );
  }

  /// Decodes barcodes directly from a local image file path (or a URL on Web).
  static Future<List<BarcodeResult>> decodeImageFile(
    String filePath, {
    bool tryHarder = true,
    bool tryRotate = true,
    bool tryInvert = true,
  }) {
    return _engine.decodeImageFile(
      filePath,
      tryHarder: tryHarder,
      tryRotate: tryRotate,
      tryInvert: tryInvert,
    );
  }

  /// Decodes barcodes from compressed image bytes (PNG, JPG, WebP, BMP).
  static Future<List<BarcodeResult>> decodeImageMemory(
    Uint8List encodedImageBytes, {
    bool tryHarder = true,
    bool tryRotate = true,
    bool tryInvert = true,
  }) {
    return _engine.decodeImageMemory(
      encodedImageBytes,
      tryHarder: tryHarder,
      tryRotate: tryRotate,
      tryInvert: tryInvert,
    );
  }

  /// Generates a PNG-encoded barcode image (`Uint8List`) for [content] using
  /// `zxing-cpp` 3.1.1 (`CreatorOptions` & `CreateBarcodeFromText`).
  static Future<Uint8List> encodeBarcode(
    String content, {
    int width = 512,
    int height = 512,
    int margin = 2,
    BarcodeEccLevel eccLevel = BarcodeEccLevel.medium,
  }) {
    return _engine.encodeBarcode(
      content,
      width: width,
      height: height,
      margin: margin,
      eccLevel: eccLevel,
    );
  }
}
