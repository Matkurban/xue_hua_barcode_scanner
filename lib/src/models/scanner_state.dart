import 'dart:ui' show Size;

import 'barcode_enums.dart';
import 'barcode_result.dart';
import 'camera_input_source.dart';

/// Immutable state snapshot exposed by `XueHuaScannerController`.
class ScannerState {
  /// Creates a [ScannerState].
  const ScannerState({
    this.isInitialized = false,
    this.isRunning = false,
    this.isPaused = false,
    this.torchState = TorchState.off,
    this.cameraFacing = CameraFacing.back,
    this.availableCameraCount = 1,
    this.cameras = const <CameraInputSource>[],
    this.activeCameraId = 'default',
    this.previewSize = const Size(1280, 720),
    this.sensorOrientation = 0,
    this.textureId,
    this.webViewType,
    this.latestResults = const <BarcodeResult>[],
    this.hasValidationError = false,
    this.lastGalleryScanStatus,
    this.errorMessage,
  });

  /// Whether the camera stream or platform engine has completed initialization.
  final bool isInitialized;

  /// Whether real-time frame capture and decoding are active.
  final bool isRunning;

  /// Whether scanning is temporarily paused by the user or lifecycle.
  final bool isPaused;

  /// Current torch/flashlight state (`off`, `on`, or `unavailable`).
  final TorchState torchState;

  /// Current active camera lens facing direction.
  final CameraFacing cameraFacing;

  /// Number of cameras detected on the current device.
  final int availableCameraCount;

  /// Enumerated cameras and other video inputs.
  ///
  /// Empty until the platform reports a list. The source picker is shown only
  /// when this list contains more than one entry.
  final List<CameraInputSource> cameras;

  /// Identifier of the active camera device.
  final String activeCameraId;

  /// Resolution of the active camera preview stream.
  final Size previewSize;

  /// Clockwise sensor orientation in degrees (`0`, `90`, `180`, `270`).
  final int sensorOrientation;

  /// Native Flutter texture ID when rendered via platform texture registry.
  final int? textureId;

  /// Registered `HtmlElementView` viewType when running on Flutter Web.
  final String? webViewType;

  /// Most recently recognized barcodes in the current frame.
  final List<BarcodeResult> latestResults;

  /// `true` when the most recently scanned barcode or selected image failed
  /// validation, causing the scanner overlay border to turn red.
  final bool hasValidationError;

  /// Status of the most recent gallery image recognition attempt.
  final GalleryScanStatus? lastGalleryScanStatus;

  /// Non-null when a camera permission or hardware error occurs.
  final String? errorMessage;

  /// Whether the current camera supports hardware torch toggling.
  bool get hasTorch => torchState != TorchState.unavailable;

  /// Whether the torch is currently illuminated.
  bool get isTorchOn => torchState == TorchState.on;

  /// Whether switching between multiple cameras is supported.
  bool get canSwitchCamera =>
      cameras.length > 1 || (cameras.isEmpty && availableCameraCount > 1);

  /// Creates a copy of this [ScannerState] with updated fields.
  ScannerState copyWith({
    bool? isInitialized,
    bool? isRunning,
    bool? isPaused,
    TorchState? torchState,
    CameraFacing? cameraFacing,
    int? availableCameraCount,
    List<CameraInputSource>? cameras,
    String? activeCameraId,
    Size? previewSize,
    int? sensorOrientation,
    int? textureId,
    String? webViewType,
    List<BarcodeResult>? latestResults,
    bool? hasValidationError,
    GalleryScanStatus? lastGalleryScanStatus,
    bool clearGalleryScanStatus = false,
    String? errorMessage,
    bool clearError = false,
  }) {
    return ScannerState(
      isInitialized: isInitialized ?? this.isInitialized,
      isRunning: isRunning ?? this.isRunning,
      isPaused: isPaused ?? this.isPaused,
      torchState: torchState ?? this.torchState,
      cameraFacing: cameraFacing ?? this.cameraFacing,
      availableCameraCount: availableCameraCount ?? this.availableCameraCount,
      cameras: cameras ?? this.cameras,
      activeCameraId: activeCameraId ?? this.activeCameraId,
      previewSize: previewSize ?? this.previewSize,
      sensorOrientation: sensorOrientation ?? this.sensorOrientation,
      textureId: textureId ?? this.textureId,
      webViewType: webViewType ?? this.webViewType,
      latestResults: latestResults ?? this.latestResults,
      hasValidationError: hasValidationError ?? this.hasValidationError,
      lastGalleryScanStatus: clearGalleryScanStatus
          ? null
          : (lastGalleryScanStatus ?? this.lastGalleryScanStatus),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}
