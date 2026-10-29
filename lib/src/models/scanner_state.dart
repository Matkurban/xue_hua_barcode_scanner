import 'dart:ui' show Size;

import 'package:flutter/foundation.dart' show listEquals;

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
    this.torchState = TorchState.unavailable,
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
    this.permissionStatus = CameraPermissionStatus.unknown,
    this.errorCode,
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

  /// Current camera authorization / permission status.
  final CameraPermissionStatus permissionStatus;

  /// Optional structured platform error code (e.g. `CAMERA_PERMISSION_DENIED`, `NO_CAMERA`).
  final String? errorCode;

  /// Non-null when a camera permission or hardware error occurs.
  final String? errorMessage;

  /// Whether the current camera supports hardware torch toggling.
  bool get hasTorch => torchState != TorchState.unavailable;

  /// Whether the torch is currently illuminated.
  bool get isTorchOn => torchState == TorchState.on;

  /// Whether switching between multiple cameras is supported.
  bool get canSwitchCamera =>
      cameras.length > 1 || (cameras.isEmpty && availableCameraCount > 1);

  /// Whether a live platform texture or Web video element is active.
  bool get hasLiveFeed =>
      textureId != null || (webViewType != null && webViewType!.isNotEmpty);

  /// Whether a camera permission or hardware error is present.
  bool get hasCameraError =>
      (errorMessage != null && errorMessage!.trim().isNotEmpty) ||
      (errorCode != null && errorCode!.trim().isNotEmpty) ||
      permissionStatus == CameraPermissionStatus.denied ||
      permissionStatus == CameraPermissionStatus.permanentlyDenied ||
      permissionStatus == CameraPermissionStatus.restricted;

  /// Whether the camera error is specifically caused by missing/denied camera permission.
  bool get isPermissionDenied {
    if (permissionStatus == CameraPermissionStatus.denied ||
        permissionStatus == CameraPermissionStatus.permanentlyDenied ||
        permissionStatus == CameraPermissionStatus.restricted) {
      return true;
    }
    final String codeUpper = (errorCode ?? '').toUpperCase();
    if (codeUpper.contains('PERMISSION') ||
        codeUpper.contains('NOT_ALLOWED') ||
        codeUpper.contains('SECURITY')) {
      return true;
    }
    final String msgLower = (errorMessage ?? '').toLowerCase();
    if (msgLower.isEmpty) {
      return false;
    }
    return msgLower.contains('permission') ||
        msgLower.contains('not authorized') ||
        msgLower.contains('authorization') ||
        msgLower.contains('notallowederror') ||
        msgLower.contains('securityexception') ||
        msgLower.contains('权限') ||
        msgLower.contains('未授权') ||
        msgLower.contains('拒绝') ||
        msgLower.contains('受限');
  }

  /// Whether camera access is restricted by system policy / MDM / parental controls.
  bool get isPermissionRestricted {
    if (permissionStatus == CameraPermissionStatus.restricted ||
        errorCode == 'CAMERA_PERMISSION_RESTRICTED') {
      return true;
    }
    final String msgLower = (errorMessage ?? '').toLowerCase();
    return msgLower.contains('restricted') ||
        msgLower.contains('受限') ||
        msgLower.contains('策略');
  }

  /// Whether the camera failure is due to missing physical camera hardware.
  bool get isNoCameraHardware {
    if (isPermissionDenied) {
      return false;
    }
    final String codeUpper = (errorCode ?? '').toUpperCase();
    if (codeUpper == 'NO_CAMERA' || codeUpper == 'NO_CAMERA_MANAGER') {
      return true;
    }
    final String msgLower = (errorMessage ?? '').toLowerCase();
    return msgLower.contains('no_camera') ||
        msgLower.contains('no camera') ||
        msgLower.contains('no webcam') ||
        msgLower.contains('no v4l2') ||
        msgLower.contains('notfounderror') ||
        msgLower.contains('未检测到') ||
        msgLower.contains('无可用');
  }

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
    CameraPermissionStatus? permissionStatus,
    String? errorCode,
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
      permissionStatus: clearError
          ? (permissionStatus ??
                (isPermissionDenied
                    ? CameraPermissionStatus.unknown
                    : this.permissionStatus))
          : (permissionStatus ?? this.permissionStatus),
      errorCode: clearError ? null : (errorCode ?? this.errorCode),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ScannerState &&
        other.isInitialized == isInitialized &&
        other.isRunning == isRunning &&
        other.isPaused == isPaused &&
        other.torchState == torchState &&
        other.cameraFacing == cameraFacing &&
        other.availableCameraCount == availableCameraCount &&
        listEquals(other.cameras, cameras) &&
        other.activeCameraId == activeCameraId &&
        other.previewSize == previewSize &&
        other.sensorOrientation == sensorOrientation &&
        other.textureId == textureId &&
        other.webViewType == webViewType &&
        listEquals(other.latestResults, latestResults) &&
        other.hasValidationError == hasValidationError &&
        other.lastGalleryScanStatus == lastGalleryScanStatus &&
        other.permissionStatus == permissionStatus &&
        other.errorCode == errorCode &&
        other.errorMessage == errorMessage;
  }

  @override
  int get hashCode => Object.hash(
    isInitialized,
    isRunning,
    isPaused,
    torchState,
    cameraFacing,
    availableCameraCount,
    Object.hashAll(cameras),
    activeCameraId,
    previewSize,
    sensorOrientation,
    textureId,
    webViewType,
    Object.hashAll(latestResults),
    hasValidationError,
    lastGalleryScanStatus,
    permissionStatus,
    errorCode,
    errorMessage,
  );
}
