import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/services.dart';

import '../core/barcode_matrix_codec.dart';
import '../core/scanner_engine_interface.dart';
import '../models/barcode_enums.dart';
import '../models/barcode_result.dart';
import '../models/camera_frame_packet.dart';
import '../models/scanner_state.dart';
import 'ffi_isolate_worker.dart';

export 'row_stride_normalizer.dart';

const MethodChannel _kCameraMethodChannel = MethodChannel(
  'com.kurban.xue_hua_barcode_scanner/methods',
);
const EventChannel _kCameraFrameEventChannel = EventChannel(
  'com.kurban.xue_hua_barcode_scanner/frames',
);

/// Native 5-platform (Android, iOS, macOS, Windows, Linux) implementation of
/// [XueHuaScannerPlatformEngine] powered by `dart:ffi`, `zxing-cpp`, and `Isolate.run`.
class XueHuaScannerFfiEngine implements XueHuaScannerPlatformEngine {
  /// Creates a native FFI scanner engine.
  XueHuaScannerFfiEngine();

  StreamSubscription<dynamic>? _frameSubscription;

  bool get _isDesktop =>
      Platform.isMacOS || Platform.isWindows || Platform.isLinux;

  @override
  bool get isWeb => false;

  @override
  String get engineVersion => readNativeEngineVersion();

  @override
  Future<List<BarcodeResult>> decodeImageBytes(
    Uint8List rawPixelBytes, {
    required int width,
    required int height,
    int rowStride = 0,
    PixelFormat format = PixelFormat.rgba8888,
    bool tryHarder = true,
    bool tryRotate = true,
    bool tryInvert = true,
  }) async {
    if (rawPixelBytes.isEmpty || width <= 0 || height <= 0) {
      return const <BarcodeResult>[];
    }
    return Isolate.run(
      () => decodeInWorkerIsolate(
        rawPixelBytes: rawPixelBytes,
        width: width,
        height: height,
        rowStride: rowStride,
        format: format,
        tryHarder: tryHarder,
        tryRotate: tryRotate,
        tryInvert: tryInvert,
      ),
    );
  }

  @override
  Future<List<BarcodeResult>> decodeImageFile(
    String filePath, {
    bool tryHarder = true,
    bool tryRotate = true,
    bool tryInvert = true,
  }) async {
    final File file = File(filePath);
    if (!await file.exists()) {
      throw FileSystemException('Image file does not exist', filePath);
    }
    final Uint8List encodedBytes = await file.readAsBytes();
    return decodeImageMemory(
      encodedBytes,
      tryHarder: tryHarder,
      tryRotate: tryRotate,
      tryInvert: tryInvert,
    );
  }

  @override
  Future<List<BarcodeResult>> decodeImageMemory(
    Uint8List encodedImageBytes, {
    bool tryHarder = true,
    bool tryRotate = true,
    bool tryInvert = true,
  }) async {
    if (encodedImageBytes.isEmpty) {
      return const <BarcodeResult>[];
    }
    final decoded = await BarcodeMatrixCodec.decodeCompressedImageToRgba(
      encodedImageBytes,
    );
    return decodeImageBytes(
      decoded.rgbaBytes,
      width: decoded.width,
      height: decoded.height,
      rowStride: decoded.width * 4,
      format: PixelFormat.rgba8888,
      tryHarder: tryHarder,
      tryRotate: tryRotate,
      tryInvert: tryInvert,
    );
  }

  @override
  Future<Uint8List> encodeBarcode(
    String content, {
    int width = 512,
    int height = 512,
    int margin = 2,
    BarcodeEccLevel eccLevel = BarcodeEccLevel.medium,
  }) async {
    if (content.trim().isEmpty) {
      throw ArgumentError.value(
        content,
        'content',
        'Barcode content cannot be empty.',
      );
    }
    final int safeWidth = width.clamp(64, 4096);
    final int safeHeight = height.clamp(64, 4096);
    final Uint8List rgbaBytes = await Isolate.run(
      () => encodeRgbaInWorkerIsolate(
        content: content,
        width: safeWidth,
        height: safeHeight,
        margin: margin,
        eccLevel: eccLevel,
      ),
    );
    return BarcodeMatrixCodec.rgbaToPngBytes(
      rgbaBytes,
      width: safeWidth,
      height: safeHeight,
    );
  }

  @override
  Future<ScannerState> startCamera({
    required CameraFacing facing,
    required void Function(CameraFramePacket frame) onFrame,
    required void Function(List<BarcodeResult> results) onWebBarcodes,
  }) async {
    await _frameSubscription?.cancel();
    _frameSubscription = null;

    final CameraFacing defaultDesktopFacing = facing == CameraFacing.back
        ? CameraFacing.front
        : facing;
    final CameraFacing effectiveFacing = _isDesktop
        ? defaultDesktopFacing
        : facing;

    try {
      final Map<Object?, Object?>? reply = await _kCameraMethodChannel
          .invokeMapMethod<Object?, Object?>('startCamera', <String, Object?>{
            'facing': effectiveFacing.name,
          });

      _frameSubscription = _kCameraFrameEventChannel
          .receiveBroadcastStream()
          .listen((dynamic event) {
            if (event is Map) {
              final Uint8List? bytes = event['bytes'] as Uint8List?;
              final int width = (event['width'] as int?) ?? 0;
              final int height = (event['height'] as int?) ?? 0;
              final int rowStride = (event['rowStride'] as int?) ?? 0;
              final int formatInt = (event['format'] as int?) ?? 0;
              final int sensorOrientation =
                  (event['sensorOrientation'] as int?) ?? 0;
              if (bytes != null && width > 0 && height > 0) {
                final PixelFormat fmt = PixelFormat.values.firstWhere(
                  (f) => f.cValue == formatInt,
                  orElse: () => PixelFormat.lum,
                );
                onFrame(
                  CameraFramePacket(
                    bytes: bytes,
                    width: width,
                    height: height,
                    rowStride: rowStride,
                    format: fmt,
                    sensorOrientation: sensorOrientation,
                  ),
                );
              }
            }
          });

      if (reply != null) {
        final bool hasTorch = (reply['hasTorch'] as bool?) ?? !_isDesktop;
        final int cameraCount =
            (reply['availableCameraCount'] as int?) ?? (_isDesktop ? 1 : 2);
        final int? textureId = reply['textureId'] as int?;
        final double previewW = ((reply['previewWidth'] as num?) ?? 1280)
            .toDouble();
        final double previewH = ((reply['previewHeight'] as num?) ?? 720)
            .toDouble();
        final int sensorOrientation =
            (reply['sensorOrientation'] as int?) ?? (_isDesktop ? 0 : 90);
        return ScannerState(
          isInitialized: true,
          isRunning: true,
          isPaused: false,
          torchState: hasTorch ? TorchState.off : TorchState.unavailable,
          cameraFacing: effectiveFacing,
          availableCameraCount: cameraCount,
          textureId: textureId,
          previewSize: Size(previewW, previewH),
          sensorOrientation: sensorOrientation,
        );
      }
    } on MissingPluginException {
      // Graceful fallback when running without a native camera host channel bound (e.g. unit tests).
    } on PlatformException catch (e) {
      return ScannerState(
        isInitialized: true,
        isRunning: false,
        isPaused: false,
        torchState: TorchState.unavailable,
        cameraFacing: effectiveFacing,
        availableCameraCount: _isDesktop ? 1 : 2,
        previewSize: const Size(1280, 720),
        sensorOrientation: _isDesktop ? 0 : 90,
        errorMessage: e.message ?? e.code,
      );
    } catch (_) {}

    return ScannerState(
      isInitialized: true,
      isRunning: true,
      isPaused: false,
      torchState: _isDesktop || effectiveFacing == CameraFacing.front
          ? TorchState.unavailable
          : TorchState.off,
      cameraFacing: effectiveFacing,
      availableCameraCount: _isDesktop ? 2 : 2,
      previewSize: const Size(1280, 720),
      sensorOrientation: _isDesktop ? 0 : 90,
    );
  }

  @override
  Future<void> stopCamera() async {
    await _frameSubscription?.cancel();
    _frameSubscription = null;
    try {
      await _kCameraMethodChannel.invokeMethod<void>('stopCamera');
    } catch (_) {}
  }

  @override
  Future<TorchState> setTorch(bool enabled) async {
    if (_isDesktop) {
      return TorchState.unavailable;
    }
    try {
      final bool? supported = await _kCameraMethodChannel.invokeMethod<bool>(
        'setTorch',
        <String, Object?>{'enabled': enabled},
      );
      if (supported == false) {
        return TorchState.unavailable;
      }
    } on MissingPluginException {
      // Simulated mobile torch state when no host channel is bound.
    } catch (_) {
      return TorchState.unavailable;
    }
    return enabled ? TorchState.on : TorchState.off;
  }

  @override
  Future<ScannerState> switchCamera({
    required CameraFacing targetFacing,
    required void Function(CameraFramePacket frame) onFrame,
    required void Function(List<BarcodeResult> results) onWebBarcodes,
  }) async {
    return startCamera(
      facing: targetFacing,
      onFrame: onFrame,
      onWebBarcodes: onWebBarcodes,
    );
  }

  @override
  Future<Uint8List?> pickImageFromGallery() async {
    try {
      final Uint8List? bytes = await _kCameraMethodChannel
          .invokeMethod<Uint8List>('pickImageFromGallery');
      if (bytes != null && bytes.isNotEmpty) {
        return bytes;
      }
      final String? filePath = await _kCameraMethodChannel.invokeMethod<String>(
        'pickImageFilePath',
      );
      if (filePath != null && filePath.isNotEmpty) {
        final File file = File(filePath);
        if (await file.exists()) {
          return await file.readAsBytes();
        }
      }
    } on MissingPluginException {
      return null;
    } catch (_) {}
    return null;
  }
}

/// Factory function exported for conditional imports.
XueHuaScannerPlatformEngine createPlatformScannerEngine() =>
    XueHuaScannerFfiEngine();
