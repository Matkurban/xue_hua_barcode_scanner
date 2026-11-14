import 'dart:async';
import 'dart:ffi' as ffi;
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'dart:ui' show Size;

import 'package:ffi/ffi.dart';

import '../core/barcode_matrix_codec.dart';
import '../core/scanner_engine_interface.dart';
import '../models/barcode_enums.dart';
import '../models/barcode_result.dart';
import '../models/camera_frame_packet.dart';
import '../models/camera_input_source.dart';
import '../models/scanner_state.dart';
import 'ffi_isolate_worker.dart';
import 'scanner_host_ffi_bindings.dart';

export 'row_stride_normalizer.dart';

class _NativeStartCameraReply {
  const _NativeStartCameraReply.success(this.state)
    : errorCode = null,
      errorMessage = null,
      errorDetails = null;

  const _NativeStartCameraReply.failure({
    required this.errorCode,
    this.errorMessage,
    this.errorDetails,
  }) : state = null;

  final ScannerState? state;
  final String? errorCode;
  final String? errorMessage;
  final String? errorDetails;
}

class _NativePickImageReply {
  const _NativePickImageReply({this.bytes, this.filePath});

  final Uint8List? bytes;
  final String? filePath;
}

class _PendingStartRequest {
  _PendingStartRequest({
    required this.completer,
    required this.requestedFacing,
    required this.requestedCameraId,
  });

  final Completer<_NativeStartCameraReply> completer;
  final CameraFacing requestedFacing;
  final String? requestedCameraId;
}

/// Isolate-local dispatcher connecting Dart `NativeCallable.listener` callbacks
/// with the native C-ABI host driver (`xh_host_*`).
class _FfiHostDispatcher {
  _FfiHostDispatcher._();

  static final _FfiHostDispatcher instance = _FfiHostDispatcher._();

  ScannerHostFfiBindings? _bindings;
  bool _bindingsLookedUp = false;

  int _nextRequestId = 1;
  int _nextGeneration = 1;
  int _sessionToken = 0;

  ffi.NativeCallable<XHHostCameraListCallbackFunction>? _cameraListCb;
  ffi.NativeCallable<XHHostStartCameraCallbackFunction>? _startCameraCb;
  ffi.NativeCallable<XHHostBoolCallbackFunction>? _boolCb;
  ffi.NativeCallable<XHHostPickImageCallbackFunction>? _pickImageCb;
  ffi.NativeCallable<XHHostFrameCallbackFunction>? _frameCb;

  final Map<int, Completer<List<CameraInputSource>>> _cameraListPending =
      <int, Completer<List<CameraInputSource>>>{};
  final Map<int, _PendingStartRequest> _startCameraPending =
      <int, _PendingStartRequest>{};
  final Map<int, Completer<bool>> _boolPending = <int, Completer<bool>>{};
  final Map<int, Completer<_NativePickImageReply>> _pickImagePending =
      <int, Completer<_NativePickImageReply>>{};

  int _activeGeneration = 0;
  XueHuaScannerFfiEngine? _activeEngine;
  void Function(CameraFramePacket frame)? _activeOnFrame;
  bool _streamPaused = false;

  ScannerHostFfiBindings? get _hostBindings {
    if (!_bindingsLookedUp) {
      _bindingsLookedUp = true;
      final ffi.DynamicLibrary? lib = tryOpenZxingDynamicLibrary(
        requiredSymbol: 'xh_host_is_attached',
      );
      if (lib != null) {
        _bindings = ScannerHostFfiBindings(lib);
      }
    }
    return _bindings;
  }

  bool get isHostAttached {
    final ScannerHostFfiBindings? bindings = _hostBindings;
    if (bindings == null) {
      return false;
    }
    try {
      return bindings.xh_host_is_attached() != 0;
    } catch (_) {
      return false;
    }
  }

  void _ensureListenersRegistered() {
    final ScannerHostFfiBindings? bindings = _hostBindings;
    if (bindings == null || _sessionToken != 0) {
      return;
    }
    _cameraListCb =
        ffi.NativeCallable<XHHostCameraListCallbackFunction>.listener(
          _onCameraListResult,
        )..keepIsolateAlive = false;
    _startCameraCb =
        ffi.NativeCallable<XHHostStartCameraCallbackFunction>.listener(
          _onStartCameraResult,
        )..keepIsolateAlive = false;
    _boolCb = ffi.NativeCallable<XHHostBoolCallbackFunction>.listener(
      _onBoolResult,
    )..keepIsolateAlive = false;
    _pickImageCb = ffi.NativeCallable<XHHostPickImageCallbackFunction>.listener(
      _onPickImageResult,
    )..keepIsolateAlive = false;
    _frameCb = ffi.NativeCallable<XHHostFrameCallbackFunction>.listener(
      _onFramePacket,
    )..keepIsolateAlive = false;

    _sessionToken = bindings.xh_host_register_callbacks(
      _cameraListCb!.nativeFunction,
      _startCameraCb!.nativeFunction,
      _boolCb!.nativeFunction,
      _pickImageCb!.nativeFunction,
      _frameCb!.nativeFunction,
    );
  }

  void _maybeUnregisterListenersIfIdle() {
    if (_sessionToken == 0) {
      return;
    }
    if (_activeEngine != null ||
        _cameraListPending.isNotEmpty ||
        _startCameraPending.isNotEmpty ||
        _boolPending.isNotEmpty ||
        _pickImagePending.isNotEmpty) {
      return;
    }
    final ScannerHostFfiBindings? bindings = _hostBindings;
    if (bindings != null) {
      try {
        bindings.xh_host_unregister_callbacks(_sessionToken);
      } catch (_) {}
    }
    _sessionToken = 0;
    _cameraListCb?.close();
    _cameraListCb = null;
    _startCameraCb?.close();
    _startCameraCb = null;
    _boolCb?.close();
    _boolCb = null;
    _pickImageCb?.close();
    _pickImageCb = null;
    _frameCb?.close();
    _frameCb = null;
  }

  int _allocateRequestId() {
    final int id = _nextRequestId++;
    if (_nextRequestId <= 0) {
      _nextRequestId = 1;
    }
    return id;
  }

  String _readCString(ffi.Pointer<ffi.Char> ptr) {
    if (ptr == ffi.nullptr) {
      return '';
    }
    return ptr.cast<Utf8>().toDartString();
  }

  String? _readNullableCString(ffi.Pointer<ffi.Char> ptr) {
    if (ptr == ffi.nullptr) {
      return null;
    }
    return ptr.cast<Utf8>().toDartString();
  }

  List<CameraInputSource> _readCameraArray(
    ffi.Pointer<XHHostCameraInfo> camerasPtr,
    int count,
  ) {
    if (camerasPtr == ffi.nullptr || count <= 0) {
      return const <CameraInputSource>[];
    }
    final List<CameraInputSource> out = <CameraInputSource>[];
    for (int i = 0; i < count; i++) {
      final XHHostCameraInfo item = camerasPtr[i];
      final String id = _readCString(item.id);
      if (id.isEmpty) {
        continue;
      }
      final String rawLabel = _readCString(item.label).trim();
      final String facingName = _readCString(item.facing);
      out.add(
        CameraInputSource(
          id: id,
          label: rawLabel.isEmpty ? id : rawLabel,
          facing: CameraInputSource.facingFromName(facingName),
        ),
      );
    }
    return out;
  }

  void _onCameraListResult(ffi.Pointer<XHHostCameraListResult> ptr) {
    try {
      if (ptr == ffi.nullptr) return;
      final XHHostCameraListResult res = ptr.ref;
      final Completer<List<CameraInputSource>>? completer = _cameraListPending
          .remove(res.request_id);
      if (completer == null || completer.isCompleted) {
        return;
      }
      if (res.ok != 0) {
        completer.complete(_readCameraArray(res.cameras, res.camera_count));
      } else {
        completer.complete(const <CameraInputSource>[]);
      }
    } finally {
      _bindings?.xh_host_free_camera_list_result(ptr);
      _maybeUnregisterListenersIfIdle();
    }
  }

  void _onStartCameraResult(ffi.Pointer<XHHostStartCameraResult> ptr) {
    try {
      if (ptr == ffi.nullptr) return;
      final XHHostStartCameraResult res = ptr.ref;
      final _PendingStartRequest? pending = _startCameraPending.remove(
        res.request_id,
      );
      if (pending == null || pending.completer.isCompleted) {
        return;
      }
      final Completer<_NativeStartCameraReply> completer = pending.completer;
      if (res.ok == 0) {
        completer.complete(
          _NativeStartCameraReply.failure(
            errorCode:
                _readNullableCString(res.error_code) ?? 'CAMERA_START_ERROR',
            errorMessage: _readNullableCString(res.error_message),
            errorDetails: _readNullableCString(res.error_details),
          ),
        );
        return;
      }
      final List<CameraInputSource> cameras = _readCameraArray(
        res.cameras,
        res.camera_count,
      );
      final String reportedFacing = _readCString(res.camera_facing);
      final String reportedActiveId = _readCString(res.active_camera_id);
      final String activeCameraId = reportedActiveId.isNotEmpty
          ? reportedActiveId
          : (pending.requestedCameraId ??
                (cameras.isNotEmpty ? cameras.first.id : 'default'));
      CameraFacing facing = reportedFacing.isEmpty
          ? pending.requestedFacing
          : CameraInputSource.facingFromName(reportedFacing);
      if (reportedFacing.isEmpty) {
        for (final CameraInputSource camera in cameras) {
          if (camera.id == activeCameraId) {
            facing = camera.facing;
            break;
          }
        }
      }
      final bool hasTorch = res.has_torch != 0;
      final int cameraCount = cameras.isNotEmpty
          ? cameras.length
          : (res.available_camera_count > 0 ? res.available_camera_count : 1);
      final int? textureId = res.texture_id >= 0 ? res.texture_id : null;
      final double previewW = (res.preview_width > 0 ? res.preview_width : 1280)
          .toDouble();
      final double previewH =
          (res.preview_height > 0 ? res.preview_height : 720).toDouble();
      final int sensorOrientation = res.sensor_orientation;

      completer.complete(
        _NativeStartCameraReply.success(
          ScannerState(
            isInitialized: true,
            isRunning: true,
            isPaused: false,
            torchState: hasTorch
                ? (res.torch_enabled != 0 ? TorchState.on : TorchState.off)
                : TorchState.unavailable,
            cameraFacing: facing,
            availableCameraCount: cameraCount,
            cameras: cameras,
            activeCameraId: activeCameraId,
            textureId: textureId,
            previewSize: Size(previewW, previewH),
            sensorOrientation: sensorOrientation,
            permissionStatus: CameraPermissionStatus.granted,
          ),
        ),
      );
    } finally {
      _bindings?.xh_host_free_start_camera_result(ptr);
      _maybeUnregisterListenersIfIdle();
    }
  }

  void _onBoolResult(ffi.Pointer<XHHostBoolResult> ptr) {
    try {
      if (ptr == ffi.nullptr) return;
      final XHHostBoolResult res = ptr.ref;
      final Completer<bool>? completer = _boolPending.remove(res.request_id);
      if (completer == null || completer.isCompleted) {
        return;
      }
      completer.complete(res.ok != 0 && res.value != 0);
    } finally {
      _bindings?.xh_host_free_bool_result(ptr);
      _maybeUnregisterListenersIfIdle();
    }
  }

  void _onPickImageResult(ffi.Pointer<XHHostPickImageResult> ptr) {
    try {
      if (ptr == ffi.nullptr) return;
      final XHHostPickImageResult res = ptr.ref;
      final Completer<_NativePickImageReply>? completer = _pickImagePending
          .remove(res.request_id);
      if (completer == null || completer.isCompleted) {
        return;
      }
      if (res.ok == 0) {
        completer.complete(const _NativePickImageReply());
        return;
      }
      Uint8List? copiedBytes;
      if (res.has_data != 0 &&
          res.bytes != ffi.nullptr &&
          res.byte_length > 0) {
        copiedBytes = Uint8List.fromList(
          res.bytes.asTypedList(res.byte_length),
        );
      }
      final String? filePath = _readNullableCString(res.file_path);
      completer.complete(
        _NativePickImageReply(bytes: copiedBytes, filePath: filePath),
      );
    } finally {
      _bindings?.xh_host_free_pick_image_result(ptr);
      _maybeUnregisterListenersIfIdle();
    }
  }

  void _onFramePacket(ffi.Pointer<XHHostFramePacket> ptr) {
    try {
      if (ptr == ffi.nullptr || _streamPaused) return;
      final XHHostFramePacket pkt = ptr.ref;
      final void Function(CameraFramePacket frame)? callback = _activeOnFrame;
      if (callback == null ||
          pkt.session_generation != _activeGeneration ||
          pkt.bytes == ffi.nullptr ||
          pkt.byte_length <= 0 ||
          pkt.width <= 0 ||
          pkt.height <= 0) {
        return;
      }
      final Uint8List copiedBytes = Uint8List.fromList(
        pkt.bytes.asTypedList(pkt.byte_length),
      );
      final PixelFormat fmt = PixelFormat.values.firstWhere(
        (PixelFormat f) => f.cValue == pkt.format,
        orElse: () => PixelFormat.lum,
      );
      callback(
        CameraFramePacket(
          bytes: copiedBytes,
          width: pkt.width,
          height: pkt.height,
          rowStride: pkt.row_stride,
          format: fmt,
          sensorOrientation: pkt.sensor_orientation,
        ),
      );
    } finally {
      _bindings?.xh_host_free_frame_packet(ptr);
    }
  }

  Future<List<CameraInputSource>> listCameras() async {
    final ScannerHostFfiBindings? bindings = _hostBindings;
    if (bindings == null || !isHostAttached) {
      return const <CameraInputSource>[];
    }
    _ensureListenersRegistered();
    final int reqId = _allocateRequestId();
    final Completer<List<CameraInputSource>> completer =
        Completer<List<CameraInputSource>>();
    _cameraListPending[reqId] = completer;
    bindings.xh_host_list_cameras(reqId);
    try {
      return await completer.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () => const <CameraInputSource>[],
      );
    } finally {
      _cameraListPending.remove(reqId);
      _maybeUnregisterListenersIfIdle();
    }
  }

  Future<_NativeStartCameraReply> startCamera({
    required XueHuaScannerFfiEngine engine,
    required CameraFacing facing,
    String? cameraId,
    required void Function(CameraFramePacket frame) onFrame,
  }) async {
    final ScannerHostFfiBindings? bindings = _hostBindings;
    if (bindings == null || !isHostAttached) {
      return const _NativeStartCameraReply.failure(errorCode: 'NO_HOST');
    }
    _ensureListenersRegistered();
    final int reqId = _allocateRequestId();
    final int generation = _nextGeneration++;
    _activeGeneration = generation;
    _activeEngine = engine;
    _activeOnFrame = onFrame;
    _streamPaused = false;

    final Completer<_NativeStartCameraReply> completer =
        Completer<_NativeStartCameraReply>();
    _startCameraPending[reqId] = _PendingStartRequest(
      completer: completer,
      requestedFacing: facing,
      requestedCameraId: cameraId,
    );

    final ffi.Pointer<Utf8> facingPtr = facing.name.toNativeUtf8();
    final ffi.Pointer<Utf8>? cameraIdPtr = cameraId?.toNativeUtf8();
    try {
      bindings.xh_host_start_camera(
        reqId,
        generation,
        facingPtr.cast<ffi.Char>(),
        cameraIdPtr?.cast<ffi.Char>() ?? ffi.nullptr,
      );
    } finally {
      malloc.free(facingPtr);
      if (cameraIdPtr != null) {
        malloc.free(cameraIdPtr);
      }
    }

    try {
      final _NativeStartCameraReply reply = await completer.future.timeout(
        const Duration(seconds: 12),
        onTimeout: () => const _NativeStartCameraReply.failure(
          errorCode: 'CAMERA_START_TIMEOUT',
          errorMessage: 'CAMERA_START_TIMEOUT',
        ),
      );
      if (reply.state == null && _activeGeneration == generation) {
        _clearActiveStreamIfMatches(engine, expectedGeneration: generation);
      }
      return reply;
    } catch (_) {
      _clearActiveStreamIfMatches(engine, expectedGeneration: generation);
      rethrow;
    } finally {
      _startCameraPending.remove(reqId);
      _maybeUnregisterListenersIfIdle();
    }
  }

  Future<void> stopCamera(XueHuaScannerFfiEngine engine) async {
    _clearActiveStreamIfMatches(engine);
    final ScannerHostFfiBindings? bindings = _hostBindings;
    if (bindings == null || !isHostAttached) {
      _maybeUnregisterListenersIfIdle();
      return;
    }
    _ensureListenersRegistered();
    final int reqId = _allocateRequestId();
    final Completer<bool> completer = Completer<bool>();
    _boolPending[reqId] = completer;
    bindings.xh_host_stop_camera(reqId);
    try {
      await completer.future.timeout(
        const Duration(seconds: 2),
        onTimeout: () => true,
      );
    } finally {
      _boolPending.remove(reqId);
      _maybeUnregisterListenersIfIdle();
    }
  }

  Future<bool> setTorch(bool enabled) async {
    final ScannerHostFfiBindings? bindings = _hostBindings;
    if (bindings == null || !isHostAttached) {
      return true;
    }
    _ensureListenersRegistered();
    final int reqId = _allocateRequestId();
    final Completer<bool> completer = Completer<bool>();
    _boolPending[reqId] = completer;
    bindings.xh_host_set_torch(reqId, enabled ? 1 : 0);
    try {
      return await completer.future.timeout(
        const Duration(seconds: 2),
        onTimeout: () => false,
      );
    } finally {
      _boolPending.remove(reqId);
      _maybeUnregisterListenersIfIdle();
    }
  }

  Future<bool> openAppSettings() async {
    final ScannerHostFfiBindings? bindings = _hostBindings;
    if (bindings == null || !isHostAttached) {
      return false;
    }
    _ensureListenersRegistered();
    final int reqId = _allocateRequestId();
    final Completer<bool> completer = Completer<bool>();
    _boolPending[reqId] = completer;
    bindings.xh_host_open_app_settings(reqId);
    try {
      return await completer.future.timeout(
        const Duration(seconds: 3),
        onTimeout: () => false,
      );
    } finally {
      _boolPending.remove(reqId);
      _maybeUnregisterListenersIfIdle();
    }
  }

  Future<_NativePickImageReply> pickImage({
    required bool preferFilePath,
  }) async {
    final ScannerHostFfiBindings? bindings = _hostBindings;
    if (bindings == null || !isHostAttached) {
      return const _NativePickImageReply();
    }
    _ensureListenersRegistered();
    final int reqId = _allocateRequestId();
    final Completer<_NativePickImageReply> completer =
        Completer<_NativePickImageReply>();
    _pickImagePending[reqId] = completer;
    bindings.xh_host_pick_image(reqId, preferFilePath ? 1 : 0);
    try {
      return await completer.future;
    } finally {
      _pickImagePending.remove(reqId);
      _maybeUnregisterListenersIfIdle();
    }
  }

  void setFrameStreamPaused(XueHuaScannerFfiEngine engine, bool paused) {
    if (_activeEngine != null && !identical(_activeEngine, engine)) {
      return;
    }
    _streamPaused = paused;
    final ScannerHostFfiBindings? bindings = _hostBindings;
    if (bindings != null && isHostAttached) {
      try {
        bindings.xh_host_set_frame_stream_paused(paused ? 1 : 0);
      } catch (_) {}
    }
  }

  bool ownsActiveEngine(XueHuaScannerFfiEngine engine) =>
      identical(_activeEngine, engine);

  void _clearActiveStreamIfMatches(
    XueHuaScannerFfiEngine engine, {
    int? expectedGeneration,
  }) {
    if (!identical(_activeEngine, engine) && _activeEngine != null) {
      return;
    }
    if (expectedGeneration != null && _activeGeneration != expectedGeneration) {
      return;
    }
    _activeGeneration = 0;
    _activeEngine = null;
    _activeOnFrame = null;
    _streamPaused = false;
  }
}

/// Native 5-platform (Android, iOS, macOS, Windows, Linux) implementation of
/// [XueHuaScannerPlatformEngine] powered cleanly by `dart:ffi`, `zxing-cpp`,
/// `NativeCallable.listener`, and a persistent background worker `Isolate`.
class XueHuaScannerFfiEngine implements XueHuaScannerPlatformEngine {
  /// Creates a native FFI scanner engine.
  XueHuaScannerFfiEngine();

  final _FfiHostDispatcher _dispatcher = _FfiHostDispatcher.instance;

  bool get _isDesktop =>
      Platform.isMacOS || Platform.isWindows || Platform.isLinux;

  @override
  bool get isWeb => false;

  @override
  String get engineVersion => readNativeEngineVersion();

  /// Opens the operating system's camera privacy / application permission settings page.
  static Future<bool> openSystemSettings() =>
      _FfiHostDispatcher.instance.openAppSettings();

  /// Pauses or resumes native camera frame emission while scanning is paused.
  void setFrameStreamPaused(bool paused) {
    _dispatcher.setFrameStreamPaused(this, paused);
  }

  @override
  Future<bool> openAppSettings() => _dispatcher.openAppSettings();

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
    return decodeWithPersistentWorker(
      rawPixelBytes: rawPixelBytes,
      width: width,
      height: height,
      rowStride: rowStride,
      format: format,
      tryHarder: tryHarder,
      tryRotate: tryRotate,
      tryInvert: tryInvert,
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
  Future<List<CameraInputSource>> listCameras() async {
    if (!_dispatcher.isHostAttached) {
      return _unboundCameras();
    }
    try {
      return await _dispatcher.listCameras();
    } catch (_) {
      return const <CameraInputSource>[];
    }
  }

  @override
  Future<ScannerState> startCamera({
    required CameraFacing facing,
    String? cameraId,
    required void Function(CameraFramePacket frame) onFrame,
    required void Function(List<BarcodeResult> results) onWebBarcodes,
  }) async {
    final bool explicitDevice = cameraId != null && cameraId.isNotEmpty;
    final CameraFacing effectiveFacing =
        (!explicitDevice && _isDesktop && facing == CameraFacing.back)
        ? CameraFacing.front
        : facing;

    if (!_dispatcher.isHostAttached) {
      // Graceful fallback when running without a native camera host attached (e.g. unit tests).
      return _unboundCameraState(
        facing: effectiveFacing,
        cameraId: explicitDevice ? cameraId : null,
      );
    }

    try {
      final _NativeStartCameraReply reply = await _dispatcher.startCamera(
        engine: this,
        facing: effectiveFacing,
        cameraId: explicitDevice ? cameraId : null,
        onFrame: onFrame,
      );
      if (reply.state != null) {
        return reply.state!;
      }

      final String code = reply.errorCode ?? 'CAMERA_START_ERROR';
      if (code == 'NO_HOST') {
        return _unboundCameraState(
          facing: effectiveFacing,
          cameraId: explicitDevice ? cameraId : null,
        );
      }

      final List<CameraInputSource> cameras = await listCameras();
      final CameraPermissionStatus permStatus = _permissionStatusFromError(
        code: code,
        details: reply.errorDetails,
        message: reply.errorMessage,
      );
      return _unboundCameraState(
        facing: effectiveFacing,
        cameraId: explicitDevice ? cameraId : null,
        cameras: cameras,
        running: false,
        permissionStatus: permStatus,
        errorCode: code,
        errorMessage: reply.errorMessage ?? code,
      );
    } catch (_) {}

    return _unboundCameraState(
      facing: effectiveFacing,
      cameraId: explicitDevice ? cameraId : null,
    );
  }

  CameraPermissionStatus _permissionStatusFromError({
    required String code,
    String? details,
    String? message,
  }) {
    final String upperCode = code.toUpperCase();
    final String lowerDetails = (details ?? '').toLowerCase();
    final String msg = (message ?? '').toLowerCase();
    if (upperCode == 'CAMERA_PERMISSION_RESTRICTED' ||
        lowerDetails.contains('restricted') ||
        msg.contains('restricted')) {
      return CameraPermissionStatus.restricted;
    }
    if (upperCode.contains('PERMISSION') ||
        upperCode.contains('NOT_AUTHORIZED') ||
        upperCode.contains('SECURITY') ||
        msg.contains('permission') ||
        msg.contains('not authorized') ||
        msg.contains('authorization')) {
      if (lowerDetails.contains('permanent') ||
          msg.contains('system settings') ||
          msg.contains('enable camera access in settings')) {
        return CameraPermissionStatus.permanentlyDenied;
      }
      return CameraPermissionStatus.denied;
    }
    return CameraPermissionStatus.unknown;
  }

  List<CameraInputSource> _unboundCameras() {
    if (_isDesktop) {
      return const <CameraInputSource>[
        CameraInputSource(
          id: 'desktop-0',
          label: '摄像头 1',
          facing: CameraFacing.external,
        ),
        CameraInputSource(
          id: 'desktop-1',
          label: '摄像头 2',
          facing: CameraFacing.external,
        ),
      ];
    }
    return const <CameraInputSource>[
      CameraInputSource(id: 'back', label: '后置相机', facing: CameraFacing.back),
      CameraInputSource(id: 'front', label: '前置相机', facing: CameraFacing.front),
    ];
  }

  ScannerState _unboundCameraState({
    required CameraFacing facing,
    String? cameraId,
    List<CameraInputSource>? cameras,
    bool running = true,
    CameraPermissionStatus permissionStatus = CameraPermissionStatus.unknown,
    String? errorCode,
    String? errorMessage,
  }) {
    final List<CameraInputSource> resolved = cameras ?? _unboundCameras();
    if (resolved.isEmpty) {
      return ScannerState(
        isInitialized: true,
        isRunning: running,
        isPaused: false,
        torchState: TorchState.unavailable,
        cameraFacing: facing,
        availableCameraCount: 1,
        activeCameraId: (cameraId == null || cameraId.isEmpty)
            ? 'default'
            : cameraId,
        previewSize: const Size(1280, 720),
        sensorOrientation: _isDesktop ? 0 : 90,
        permissionStatus: permissionStatus,
        errorCode: errorCode,
        errorMessage: errorMessage,
      );
    }
    CameraInputSource active = resolved.first;
    if (cameraId != null && cameraId.isNotEmpty) {
      for (final CameraInputSource camera in resolved) {
        if (camera.id == cameraId) {
          active = camera;
          break;
        }
      }
    } else {
      for (final CameraInputSource camera in resolved) {
        if (camera.facing == facing) {
          active = camera;
          break;
        }
      }
    }
    return ScannerState(
      isInitialized: true,
      isRunning: running,
      isPaused: false,
      torchState: TorchState.unavailable,
      cameraFacing: active.facing,
      availableCameraCount: resolved.length,
      cameras: resolved,
      activeCameraId: active.id,
      previewSize: const Size(1280, 720),
      sensorOrientation: _isDesktop ? 0 : 90,
      permissionStatus: permissionStatus,
      errorCode: errorCode,
      errorMessage: errorMessage,
    );
  }

  @override
  Future<void> stopCamera() => _dispatcher.stopCamera(this);

  @override
  Future<void> dispose() async {
    if (_dispatcher.ownsActiveEngine(this)) {
      await stopCamera();
    }
  }

  @override
  Future<TorchState> setTorch(bool enabled) async {
    if (_isDesktop) {
      return TorchState.unavailable;
    }
    if (!_dispatcher.isHostAttached) {
      // Simulated mobile torch state when running without an attached native host.
      return enabled ? TorchState.on : TorchState.off;
    }
    try {
      final bool supported = await _dispatcher.setTorch(enabled);
      if (!supported) {
        return TorchState.unavailable;
      }
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
    if (!_dispatcher.isHostAttached) {
      return null;
    }
    try {
      final _NativePickImageReply reply = await _dispatcher.pickImage(
        preferFilePath: Platform.isWindows || Platform.isLinux,
      );
      if (reply.bytes != null && reply.bytes!.isNotEmpty) {
        return reply.bytes;
      }
      final String? filePath = reply.filePath;
      if (filePath != null && filePath.isNotEmpty) {
        final File file = File(filePath);
        if (await file.exists()) {
          return await file.readAsBytes();
        }
      }
    } catch (_) {}
    return null;
  }
}

/// Factory function exported for conditional imports.
XueHuaScannerPlatformEngine createPlatformScannerEngine() =>
    XueHuaScannerFfiEngine();
