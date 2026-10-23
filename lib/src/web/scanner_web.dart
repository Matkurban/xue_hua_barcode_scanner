// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';
import 'dart:ui' show Size;
import 'dart:ui_web' as ui_web;

import 'package:flutter_web_plugins/flutter_web_plugins.dart';

import '../core/barcode_matrix_codec.dart';
import '../core/scanner_engine_interface.dart';
import '../models/barcode_enums.dart';
import '../models/barcode_result.dart';
import '../models/camera_frame_packet.dart';
import '../models/scanner_state.dart';
import 'web_barcode_decoder.dart';
import 'web_js_interop.dart';

/// Web implementation of `xue_hua_barcode_scanner` bridging `zxing-wasm`,
/// the browser's native `BarcodeDetector` API, and `navigator.mediaDevices.getUserMedia`.
class XueHuaBarcodeScannerWeb implements XueHuaScannerPlatformEngine {
  /// Creates a [XueHuaBarcodeScannerWeb] instance.
  XueHuaBarcodeScannerWeb();

  /// Registers the Web plugin with the Flutter Web plugin registrar.
  static void registerWith(Registrar registrar) {}

  static int _nextViewId = 0;

  JSObject? _videoElement;
  JSObject? _canvasElement;
  JSObject? _canvasContext2d;
  JSObject? _activeMediaStream;
  JSObject? _activeVideoTrack;
  Timer? _framePollTimer;
  String? _currentViewType;
  bool _isDecodingWebFrame = false;

  @override
  bool get isWeb => true;

  @override
  String get engineVersion {
    if (jsWindow.has('ZXingWasm')) {
      return 'zxing-wasm 3.1.1 (dart:js_interop)';
    }
    if (jsWindow.has('BarcodeDetector')) {
      return 'Web BarcodeDetector + zxing-wasm fallback';
    }
    return 'zxing-wasm bridge (dart:js_interop)';
  }

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

    final Uint8List rgbaBytes = convertToTightRgba(
      rawPixelBytes,
      width: width,
      height: height,
      rowStride: rowStride,
      format: format,
    );

    final List<BarcodeResult> wasmResults = await tryDecodeWithZxingWasm(
      rgbaBytes,
      width: width,
      height: height,
      tryHarder: tryHarder,
      tryRotate: tryRotate,
      tryInvert: tryInvert,
    );
    if (wasmResults.isNotEmpty) {
      return wasmResults;
    }

    final List<BarcodeResult> detectorResults =
        await tryDecodeWithBrowserBarcodeDetector(
          rgbaBytes,
          width: width,
          height: height,
        );
    if (detectorResults.isNotEmpty) {
      return detectorResults;
    }

    return BarcodeMatrixCodec.tryDecodeFallbackMatrix(
      rgbaBytes,
      width: width,
      height: height,
      rowStride: width * 4,
      format: PixelFormat.rgba8888,
    );
  }

  @override
  Future<List<BarcodeResult>> decodeImageFile(
    String filePath, {
    bool tryHarder = true,
    bool tryRotate = true,
    bool tryInvert = true,
  }) async {
    try {
      final JSPromise<JSObject> fetchPromise = jsWindow
          .callMethod<JSPromise<JSObject>>('fetch'.toJS, filePath.toJS);
      final JSObject response = await fetchPromise.toDart;
      final JSPromise<JSArrayBuffer> bufferPromise = response
          .callMethod<JSPromise<JSArrayBuffer>>('arrayBuffer'.toJS);
      final JSArrayBuffer arrayBuffer = await bufferPromise.toDart;
      final Uint8List encodedBytes = arrayBuffer.toDart.asUint8List();
      return await decodeImageMemory(
        encodedBytes,
        tryHarder: tryHarder,
        tryRotate: tryRotate,
        tryInvert: tryInvert,
      );
    } catch (_) {
      return const <BarcodeResult>[];
    }
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

    final Uint8List rgba = BarcodeMatrixCodec.generateFallbackRgbaBarcode(
      content,
      width: safeWidth,
      height: safeHeight,
      margin: margin,
    );
    return BarcodeMatrixCodec.rgbaToPngBytes(
      rgba,
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
    await stopCamera();

    final String viewType = 'xue_hua_barcode_scanner_video_${++_nextViewId}';
    _currentViewType = viewType;

    final JSObject video = createDomElement('video');
    video.setProperty('autoplay'.toJS, true.toJS);
    video.setProperty('muted'.toJS, true.toJS);
    video.setProperty('playsInline'.toJS, true.toJS);
    video.callMethod<JSAny?>(
      'setAttribute'.toJS,
      'playsinline'.toJS,
      'true'.toJS,
    );

    final JSObject? style = video.getProperty<JSObject?>('style'.toJS);
    if (style != null) {
      style.setProperty('width'.toJS, '100%'.toJS);
      style.setProperty('height'.toJS, '100%'.toJS);
      style.setProperty('objectFit'.toJS, 'cover'.toJS);
      style.setProperty('backgroundColor'.toJS, '#000000'.toJS);
    }
    _videoElement = video;

    ui_web.platformViewRegistry.registerViewFactory(
      viewType,
      (int viewId) => video,
    );

    bool hasTorch = false;
    int cameraCount = 1;
    const Size previewSize = Size(1280, 720);

    try {
      final JSObject? mediaDevices = jsNavigator.getProperty<JSObject?>(
        'mediaDevices'.toJS,
      );
      if (mediaDevices != null) {
        final String facingModeStr = facing == CameraFacing.front
            ? 'user'
            : 'environment';
        final JSObject videoConstraints = JSObject();
        videoConstraints.setProperty('facingMode'.toJS, facingModeStr.toJS);
        videoConstraints.setProperty('width'.toJS, 1280.toJS);
        videoConstraints.setProperty('height'.toJS, 720.toJS);

        final JSObject constraints = JSObject();
        constraints.setProperty('audio'.toJS, false.toJS);
        constraints.setProperty('video'.toJS, videoConstraints);

        final JSPromise<JSObject> streamPromise = mediaDevices
            .callMethod<JSPromise<JSObject>>('getUserMedia'.toJS, constraints);
        final JSObject stream = await streamPromise.toDart;
        _activeMediaStream = stream;
        video.setProperty('srcObject'.toJS, stream);
        video.callMethod<JSAny?>('play'.toJS);

        final JSArray<JSObject> tracks = stream.callMethod<JSArray<JSObject>>(
          'getVideoTracks'.toJS,
        );
        final List<JSObject> dartTracks = tracks.toDart;
        if (dartTracks.isNotEmpty) {
          final JSObject track = dartTracks.first;
          _activeVideoTrack = track;
          if (track.has('getCapabilities')) {
            final JSObject? caps = track.callMethod<JSObject?>(
              'getCapabilities'.toJS,
            );
            if (caps != null && caps.has('torch')) {
              final JSAny? torchCap = caps.getProperty<JSAny?>('torch'.toJS);
              hasTorch = torchCap.dartify() == true;
            }
          }
        }

        if (mediaDevices.has('enumerateDevices')) {
          final JSPromise<JSArray<JSObject>> devicesPromise = mediaDevices
              .callMethod<JSPromise<JSArray<JSObject>>>(
                'enumerateDevices'.toJS,
              );
          final List<JSObject> devices = (await devicesPromise.toDart).toDart;
          int count = 0;
          for (final dev in devices) {
            final String? kind = dev
                .getProperty<JSAny?>('kind'.toJS)
                ?.dartify()
                ?.toString();
            if (kind == 'videoinput') {
              count++;
            }
          }
          if (count > 0) {
            cameraCount = count;
          }
        }

        final JSObject canvas = createDomElement('canvas');
        _canvasElement = canvas;
        _canvasContext2d = canvas.callMethod<JSObject?>(
          'getContext'.toJS,
          '2d'.toJS,
        );

        _framePollTimer = Timer.periodic(
          const Duration(milliseconds: 150),
          (_) => _pollWebVideoFrame(
            onFrame: onFrame,
            onWebBarcodes: onWebBarcodes,
          ),
        );
      }
    } catch (_) {}

    return ScannerState(
      isInitialized: true,
      isRunning: true,
      isPaused: false,
      torchState: hasTorch ? TorchState.off : TorchState.unavailable,
      cameraFacing: facing,
      availableCameraCount: cameraCount,
      webViewType: _currentViewType,
      previewSize: previewSize,
      sensorOrientation: 0,
    );
  }

  Future<void> _pollWebVideoFrame({
    required void Function(CameraFramePacket frame) onFrame,
    required void Function(List<BarcodeResult> results) onWebBarcodes,
  }) async {
    if (_isDecodingWebFrame) return;
    final JSObject? video = _videoElement;
    final JSObject? canvas = _canvasElement;
    final JSObject? ctx = _canvasContext2d;
    if (video == null || canvas == null || ctx == null) return;

    final int readyState =
        (video.getProperty<JSNumber?>('readyState'.toJS)?.toDartInt) ?? 0;
    final int videoWidth =
        (video.getProperty<JSNumber?>('videoWidth'.toJS)?.toDartInt) ?? 0;
    final int videoHeight =
        (video.getProperty<JSNumber?>('videoHeight'.toJS)?.toDartInt) ?? 0;
    if (readyState < 2 || videoWidth <= 0 || videoHeight <= 0) {
      return;
    }

    _isDecodingWebFrame = true;
    try {
      canvas.setProperty('width'.toJS, videoWidth.toJS);
      canvas.setProperty('height'.toJS, videoHeight.toJS);
      ctx.callMethodVarArgs<JSAny?>('drawImage'.toJS, <JSAny?>[
        video,
        0.toJS,
        0.toJS,
        videoWidth.toJS,
        videoHeight.toJS,
      ]);
      final JSObject? imageData = ctx.callMethodVarArgs<JSObject?>(
        'getImageData'.toJS,
        <JSAny?>[0.toJS, 0.toJS, videoWidth.toJS, videoHeight.toJS],
      );
      if (imageData != null) {
        final JSUint8ClampedArray? clamped = imageData
            .getProperty<JSUint8ClampedArray?>('data'.toJS);
        if (clamped != null) {
          final Uint8List rgba = Uint8List.sublistView(clamped.toDart);
          final List<BarcodeResult> results = await decodeImageBytes(
            rgba,
            width: videoWidth,
            height: videoHeight,
            rowStride: videoWidth * 4,
            format: PixelFormat.rgba8888,
          );
          if (results.isNotEmpty) {
            onWebBarcodes(results);
          }
        }
      }
    } catch (_) {
    } finally {
      _isDecodingWebFrame = false;
    }
  }

  @override
  Future<void> stopCamera() async {
    _framePollTimer?.cancel();
    _framePollTimer = null;
    try {
      final JSObject? stream = _activeMediaStream;
      if (stream != null) {
        final JSArray<JSObject> tracks = stream.callMethod<JSArray<JSObject>>(
          'getTracks'.toJS,
        );
        for (final JSObject track in tracks.toDart) {
          track.callMethod<JSAny?>('stop'.toJS);
        }
      }
    } catch (_) {}
    _activeMediaStream = null;
    _activeVideoTrack = null;
  }

  @override
  Future<TorchState> setTorch(bool enabled) async {
    final JSObject? track = _activeVideoTrack;
    if (track == null) {
      return TorchState.unavailable;
    }
    try {
      final JSObject torchConstraint = JSObject();
      torchConstraint.setProperty('torch'.toJS, enabled.toJS);
      final JSArray<JSObject> advancedList = <JSObject>[torchConstraint].toJS;
      final JSObject constraints = JSObject();
      constraints.setProperty('advanced'.toJS, advancedList);

      final JSPromise<JSAny?> promise = track.callMethod<JSPromise<JSAny?>>(
        'applyConstraints'.toJS,
        constraints,
      );
      await promise.toDart;
      return enabled ? TorchState.on : TorchState.off;
    } catch (_) {
      return TorchState.unavailable;
    }
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
    final Completer<Uint8List?> completer = Completer<Uint8List?>();
    try {
      final JSObject input = createDomElement('input');
      input.setProperty('type'.toJS, 'file'.toJS);
      input.setProperty('accept'.toJS, 'image/*'.toJS);

      input.setProperty(
        'onchange'.toJS,
        ((JSAny? _) {
          final JSObject? files = input.getProperty<JSObject?>('files'.toJS);
          if (files == null) {
            if (!completer.isCompleted) completer.complete(null);
            return;
          }
          final int length =
              (files.getProperty<JSNumber?>('length'.toJS)?.toDartInt) ?? 0;
          if (length <= 0) {
            if (!completer.isCompleted) completer.complete(null);
            return;
          }
          final JSObject? file = files.callMethod<JSObject?>(
            'item'.toJS,
            0.toJS,
          );
          if (file == null) {
            if (!completer.isCompleted) completer.complete(null);
            return;
          }
          final JSObject reader = jsWindow.callMethod<JSObject>(
            'eval'.toJS,
            'new FileReader()'.toJS,
          );
          reader.setProperty(
            'onload'.toJS,
            ((JSAny? _) {
              final JSArrayBuffer? result = reader.getProperty<JSArrayBuffer?>(
                'result'.toJS,
              );
              if (!completer.isCompleted) {
                completer.complete(result?.toDart.asUint8List());
              }
            }).toJS,
          );
          reader.setProperty(
            'onerror'.toJS,
            ((JSAny? _) {
              if (!completer.isCompleted) completer.complete(null);
            }).toJS,
          );
          reader.callMethod<JSAny?>('readAsArrayBuffer'.toJS, file);
        }).toJS,
      );

      input.callMethod<JSAny?>('click'.toJS);
    } catch (_) {
      if (!completer.isCompleted) completer.complete(null);
    }
    return completer.future;
  }
}

/// Factory function exported for conditional imports on Web.
XueHuaScannerPlatformEngine createPlatformScannerEngine() =>
    XueHuaBarcodeScannerWeb();
