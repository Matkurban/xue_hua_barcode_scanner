import 'dart:typed_data';

import '../models/barcode_models.dart';

/// Platform-agnostic interface implemented by both the native `dart:ffi` engine
/// (Android, iOS, macOS, Windows, Linux) and the Web `dart:js_interop` / Wasm engine.
abstract class XueHuaScannerPlatformEngine {
  /// Returns the underlying engine version description.
  String get engineVersion;

  /// Whether the current platform is running on Web.
  bool get isWeb;

  /// Decodes one or more barcodes from raw pixel bytes.
  ///
  /// Supports single-channel `PixelFormat.lum` (YUV420 / NV21 Y-plane) as well
  /// as `PixelFormat.rgba8888`, `PixelFormat.bgra8888`, and `PixelFormat.rgb888`.
  Future<List<BarcodeResult>> decodeImageBytes(
    Uint8List rawPixelBytes, {
    required int width,
    required int height,
    int rowStride = 0,
    PixelFormat format = PixelFormat.rgba8888,
    bool tryHarder = true,
    bool tryRotate = true,
    bool tryInvert = true,
  });

  /// Decodes barcodes from an image file path on the local filesystem
  /// (or a blob/data URL on Web).
  Future<List<BarcodeResult>> decodeImageFile(
    String filePath, {
    bool tryHarder = true,
    bool tryRotate = true,
    bool tryInvert = true,
  });

  /// Decodes barcodes from encoded image bytes (PNG, JPEG, WebP, BMP).
  Future<List<BarcodeResult>> decodeImageMemory(
    Uint8List encodedImageBytes, {
    bool tryHarder = true,
    bool tryRotate = true,
    bool tryInvert = true,
  });

  /// Generates a PNG-encoded barcode image buffer for [content] using `zxing-cpp`.
  Future<Uint8List> encodeBarcode(
    String content, {
    int width = 512,
    int height = 512,
    int margin = 2,
    BarcodeEccLevel eccLevel = BarcodeEccLevel.medium,
  });

  /// Lists cameras and other video inputs without changing the active device.
  Future<List<CameraInputSource>> listCameras();

  /// Starts the platform camera stream and invokes [onFrame] or [onWebBarcodes].
  ///
  /// When [cameraId] is null, the platform opens its default camera for
  /// [facing]. When [cameraId] is set, that exact input source is opened.
  Future<ScannerState> startCamera({
    required CameraFacing facing,
    String? cameraId,
    required void Function(CameraFramePacket frame) onFrame,
    required void Function(List<BarcodeResult> results) onWebBarcodes,
  });

  /// Stops the active platform camera stream.
  Future<void> stopCamera();

  /// Toggles the hardware torch / flashlight on or off.
  Future<TorchState> setTorch(bool enabled);

  /// Switches between front, back, or external cameras.
  Future<ScannerState> switchCamera({
    required CameraFacing targetFacing,
    required void Function(CameraFramePacket frame) onFrame,
    required void Function(List<BarcodeResult> results) onWebBarcodes,
  });

  /// Opens the platform gallery / file picker and returns the selected image's encoded bytes.
  Future<Uint8List?> pickImageFromGallery();
}
