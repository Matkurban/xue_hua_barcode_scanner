import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/scanner_engine_interface.dart';
import '../core/scanner_engine_selector.dart';
import '../models/barcode_models.dart';

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

/// Controller for managing real-time camera scanning, hardware torch/flashlight,
/// front/back/external camera switching, frame throttling, and gallery recognition
/// across Android, iOS, macOS, Windows, Linux, and Web.
class XueHuaScannerController extends ValueNotifier<ScannerState> {
  /// Creates a [XueHuaScannerController].
  XueHuaScannerController({
    this.initialFacing = CameraFacing.back,
    this.scanInterval = const Duration(milliseconds: 120),
    this.tryHarder = true,
    this.tryRotate = true,
    this.tryInvert = true,
    this.autoPauseOnDetect = false,
    this.onDetect,
    XueHuaScannerPlatformEngine? engine,
  }) : _engine = engine ?? XueHuaBarcodeScanner.engine,
       super(ScannerState(cameraFacing: initialFacing));

  /// Initial camera lens direction when [start] is called.
  final CameraFacing initialFacing;

  /// Minimum interval between consecutive frame decodes to prevent CPU/UI starvation.
  final Duration scanInterval;

  /// Whether to enable `ZXing::ReaderOptions::setTryHarder(true)`.
  final bool tryHarder;

  /// Whether to enable `ZXing::ReaderOptions::setTryRotate(true)`.
  final bool tryRotate;

  /// Whether to enable `ZXing::ReaderOptions::setTryInvert(true)` for dark-mode barcodes.
  final bool tryInvert;

  /// Whether to automatically pause scanning as soon as a valid barcode is detected.
  final bool autoPauseOnDetect;

  /// Optional callback invoked whenever one or more barcodes are recognized.
  final void Function(List<BarcodeResult> results)? onDetect;

  final XueHuaScannerPlatformEngine _engine;
  final StreamController<List<BarcodeResult>> _barcodesStreamController =
      StreamController<List<BarcodeResult>>.broadcast();

  bool _isProcessingFrame = false;
  DateTime _lastDecodeTimestamp = DateTime.fromMillisecondsSinceEpoch(0);
  bool _isDisposed = false;

  /// Broadcast stream of detected [BarcodeResult] lists.
  Stream<List<BarcodeResult>> get barcodesStream =>
      _barcodesStreamController.stream;

  /// Explicit [ValueListenable] of [ScannerState] for `ValueListenableBuilder`.
  ValueListenable<ScannerState> get stateListenable => this;

  /// Whether the current platform is running on Web.
  bool get isWeb => _engine.isWeb;

  /// Starts the camera stream and begins real-time barcode recognition.
  Future<void> start() async {
    if (_isDisposed) return;
    try {
      final ScannerState newState = await _engine.startCamera(
        facing: value.cameraFacing,
        onFrame: processCameraFrame,
        onWebBarcodes: _handleDetectedResults,
      );
      if (!_isDisposed) {
        value = newState;
      }
    } catch (e) {
      if (!_isDisposed) {
        value = value.copyWith(
          isInitialized: true,
          isRunning: false,
          errorMessage: e.toString(),
        );
      }
    }
  }

  /// Stops the active camera stream and releases hardware resources.
  Future<void> stop() async {
    if (_isDisposed) return;
    await _engine.stopCamera();
    if (!_isDisposed) {
      value = value.copyWith(
        isRunning: false,
        isPaused: false,
        torchState: value.hasTorch ? TorchState.off : TorchState.unavailable,
      );
    }
  }

  /// Temporarily pauses real-time frame decoding while keeping the controller alive.
  Future<void> pause() async {
    if (_isDisposed || !value.isRunning || value.isPaused) return;
    value = value.copyWith(isPaused: true);
  }

  /// Resumes real-time frame decoding after [pause].
  Future<void> resume() async {
    if (_isDisposed || !value.isRunning || !value.isPaused) return;
    value = value.copyWith(
      isPaused: false,
      latestResults: const <BarcodeResult>[],
      clearError: true,
    );
  }

  /// Toggles the hardware torch / flashlight on or off.
  Future<bool> toggleTorch() async {
    if (_isDisposed || !value.hasTorch) {
      return false;
    }
    final bool targetEnabled = !value.isTorchOn;
    final TorchState newTorchState = await _engine.setTorch(targetEnabled);
    if (!_isDisposed) {
      value = value.copyWith(torchState: newTorchState);
    }
    return newTorchState == TorchState.on;
  }

  /// Switches between rear (`CameraFacing.back`) and front (`CameraFacing.front`)
  /// cameras (or cycles external USB cameras on desktop).
  Future<void> switchCamera() async {
    if (_isDisposed) return;
    final CameraFacing nextFacing = value.cameraFacing == CameraFacing.back
        ? CameraFacing.front
        : CameraFacing.back;
    final ScannerState switchedState = await _engine.switchCamera(
      targetFacing: nextFacing,
      onFrame: processCameraFrame,
      onWebBarcodes: _handleDetectedResults,
    );
    if (!_isDisposed) {
      value = switchedState;
    }
  }

  /// Feeds a raw [CameraFramePacket] into the throttled worker Isolate decoder.
  Future<void> processCameraFrame(CameraFramePacket frame) async {
    if (_isDisposed ||
        !value.isRunning ||
        value.isPaused ||
        _isProcessingFrame) {
      return;
    }
    final DateTime now = DateTime.now();
    if (now.difference(_lastDecodeTimestamp) < scanInterval) {
      return;
    }

    _isProcessingFrame = true;
    _lastDecodeTimestamp = now;
    try {
      final List<BarcodeResult> results = await _engine.decodeImageBytes(
        frame.bytes,
        width: frame.width,
        height: frame.height,
        rowStride: frame.rowStride,
        format: frame.format,
        tryHarder: tryHarder,
        tryRotate: tryRotate,
        tryInvert: tryInvert,
      );
      if (!_isDisposed && results.isNotEmpty) {
        _handleDetectedResults(results);
      }
    } catch (_) {
    } finally {
      _isProcessingFrame = false;
    }
  }

  /// Opens the local photo gallery (or file chooser on Desktop/Web) to pick an
  /// image and decode any barcodes inside it.
  Future<List<BarcodeResult>> analyzeImageFromGallery({
    Uint8List? fallbackImageBytes,
  }) async {
    if (_isDisposed) return const <BarcodeResult>[];
    Uint8List? imageBytes = await _engine.pickImageFromGallery();
    imageBytes ??= fallbackImageBytes;
    if (imageBytes == null || imageBytes.isEmpty) {
      return const <BarcodeResult>[];
    }
    final List<BarcodeResult> results = await _engine.decodeImageMemory(
      imageBytes,
      tryHarder: true,
      tryRotate: true,
      tryInvert: true,
    );
    if (!_isDisposed && results.isNotEmpty) {
      _handleDetectedResults(results);
    }
    return results;
  }

  /// Directly analyzes an image file at [filePath] and emits any detected barcodes.
  Future<List<BarcodeResult>> analyzeImageFile(String filePath) async {
    if (_isDisposed) return const <BarcodeResult>[];
    final List<BarcodeResult> results = await _engine.decodeImageFile(
      filePath,
      tryHarder: true,
      tryRotate: true,
      tryInvert: true,
    );
    if (!_isDisposed && results.isNotEmpty) {
      _handleDetectedResults(results);
    }
    return results;
  }

  /// Simulates detecting a barcode with [content] (useful for desktop/simulator
  /// testing when no physical barcode card is held in front of the webcam).
  Future<List<BarcodeResult>> simulateBarcodeDetection(String content) async {
    if (_isDisposed) return const <BarcodeResult>[];
    final Uint8List pngBytes = await _engine.encodeBarcode(
      content,
      width: 360,
      height: 360,
      margin: 2,
    );
    final List<BarcodeResult> decoded = await _engine.decodeImageMemory(
      pngBytes,
    );
    if (!_isDisposed && decoded.isNotEmpty) {
      _handleDetectedResults(decoded);
    }
    return decoded;
  }

  void _handleDetectedResults(List<BarcodeResult> results) {
    if (_isDisposed || results.isEmpty) return;
    value = value.copyWith(
      latestResults: results,
      isPaused: autoPauseOnDetect ? true : value.isPaused,
      clearError: true,
    );
    if (!_barcodesStreamController.isClosed) {
      _barcodesStreamController.add(results);
    }
    onDetect?.call(results);
  }

  @override
  void dispose() {
    _isDisposed = true;
    unawaited(_engine.stopCamera());
    unawaited(_barcodesStreamController.close());
    super.dispose();
  }
}
