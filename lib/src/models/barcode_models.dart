import 'dart:typed_data';
import 'dart:ui' show Offset, Rect, Size;

/// Validation callback used to verify whether a decoded [BarcodeResult] meets
/// business rules (e.g. specific URL prefix, format, or payload structure).
///
/// Returning `false` marks the scan state with `hasValidationError = true` and
/// turns the scanner cutout border red.
typedef XueHuaBarcodeValidator = bool Function(BarcodeResult result);

/// Encapsulates all customizable UI text strings in `XueHuaBarcodeScannerPage`
/// and `XueHuaScannerView` for internationalization (i18n) and localization.
class XueHuaScannerTexts {
  /// Creates a [XueHuaScannerTexts] configuration with localized strings.
  const XueHuaScannerTexts({
    this.hintText = '将二维码放入框内',
    this.invalidBarcodeText = '二维码不符合要求',
    this.noBarcodeInImageText = '未在所选图片中识别到二维码或条码',
    this.torchOnLabel = '轻触关闭',
    this.torchOffLabel = '手电筒',
    this.galleryLabel = '相册',
    this.backButtonTooltip = '返回',
    this.switchCameraTooltip = '切换前后摄像头',
    this.torchUnsupportedMessage = '当前摄像头或桌面设备不支持手电筒闪光灯',
    this.cameraUnavailablePrefix = '相机不可用: ',
    this.frontCameraPreviewText = '前置相机取景中',
    this.backCameraPreviewText = '后置相机取景中',
  });

  /// Prompt displayed in the top region during normal scanning.
  final String hintText;

  /// Prompt and error feedback displayed when a scanned barcode fails validation.
  final String invalidBarcodeText;

  /// Feedback message displayed when a gallery image contains no recognizable barcode.
  final String noBarcodeInImageText;

  /// Label displayed below the torch button when the flashlight is active.
  final String torchOnLabel;

  /// Label displayed below the torch button when the flashlight is off.
  final String torchOffLabel;

  /// Label displayed below the gallery picker button.
  final String galleryLabel;

  /// Tooltip for the top-left back navigation button.
  final String backButtonTooltip;

  /// Tooltip for the top-right camera switch button.
  final String switchCameraTooltip;

  /// Message shown when the user taps the torch button on a device without flash.
  final String torchUnsupportedMessage;

  /// Prefix shown when camera initialization fails with an error.
  final String cameraUnavailablePrefix;

  /// Placeholder label shown while the front camera stream is initializing.
  final String frontCameraPreviewText;

  /// Placeholder label shown while the rear camera stream is initializing.
  final String backCameraPreviewText;

  /// Creates a copy of this [XueHuaScannerTexts] with selected fields replaced.
  XueHuaScannerTexts copyWith({
    String? hintText,
    String? invalidBarcodeText,
    String? noBarcodeInImageText,
    String? torchOnLabel,
    String? torchOffLabel,
    String? galleryLabel,
    String? backButtonTooltip,
    String? switchCameraTooltip,
    String? torchUnsupportedMessage,
    String? cameraUnavailablePrefix,
    String? frontCameraPreviewText,
    String? backCameraPreviewText,
  }) {
    return XueHuaScannerTexts(
      hintText: hintText ?? this.hintText,
      invalidBarcodeText: invalidBarcodeText ?? this.invalidBarcodeText,
      noBarcodeInImageText: noBarcodeInImageText ?? this.noBarcodeInImageText,
      torchOnLabel: torchOnLabel ?? this.torchOnLabel,
      torchOffLabel: torchOffLabel ?? this.torchOffLabel,
      galleryLabel: galleryLabel ?? this.galleryLabel,
      backButtonTooltip: backButtonTooltip ?? this.backButtonTooltip,
      switchCameraTooltip: switchCameraTooltip ?? this.switchCameraTooltip,
      torchUnsupportedMessage:
          torchUnsupportedMessage ?? this.torchUnsupportedMessage,
      cameraUnavailablePrefix:
          cameraUnavailablePrefix ?? this.cameraUnavailablePrefix,
      frontCameraPreviewText:
          frontCameraPreviewText ?? this.frontCameraPreviewText,
      backCameraPreviewText:
          backCameraPreviewText ?? this.backCameraPreviewText,
    );
  }
}

/// Outcome of picking and analyzing an image from the system gallery.
enum GalleryScanStatus {
  /// The user cancelled the gallery picker without selecting an image.
  cancelled,

  /// One or more valid barcodes were decoded and passed validation.
  success,

  /// An image was selected, but no barcode could be recognized in it.
  noBarcodeFound,

  /// A barcode was recognized in the image, but it failed validation.
  invalidBarcode,
}

/// Raw pixel buffer format passed to `decodeImageBytes`.
///
/// Supports single-channel luminance (`lum` / Y-plane of YUV420 / NV21 for
/// zero-copy camera stream decoding) as well as packed RGB/RGBA/BGRA formats.
enum PixelFormat {
  /// Single-channel 8-bit grayscale / Y-plane of YUV420 or NV21 (1 byte/pixel).
  lum(0, 1),

  /// 4-channel Red-Green-Blue-Alpha (4 bytes/pixel).
  rgba8888(1, 4),

  /// 4-channel Blue-Green-Red-Alpha, standard on iOS/macOS CoreVideo (4 bytes/pixel).
  bgra8888(2, 4),

  /// 3-channel Red-Green-Blue (3 bytes/pixel).
  rgb888(3, 3);

  const PixelFormat(this.cValue, this.bytesPerPixel);

  /// Integer constant matching `CPixelFormat` in `src/zxing_ffi_bridge.h`.
  final int cValue;

  /// Number of bytes per pixel in a tightly packed row.
  final int bytesPerPixel;
}

/// Supported 2D and 1D barcode formats recognized by `zxing-cpp` 3.1.1.
enum BarcodeFormat {
  unknown(0, 'UNKNOWN'),
  qrCode(1, 'QR_CODE'),
  microQrCode(2, 'MICRO_QR_CODE'),
  rmqrCode(3, 'RMQR_CODE'),
  dataMatrix(4, 'DATA_MATRIX'),
  aztec(5, 'AZTEC'),
  pdf417(6, 'PDF_417'),
  code128(7, 'CODE_128'),
  code39(8, 'CODE_39'),
  ean13(9, 'EAN_13'),
  ean8(10, 'EAN_8'),
  upcA(11, 'UPC_A'),
  upcE(12, 'UPC_E'),
  itf(13, 'ITF'),
  codabar(14, 'CODABAR'),
  code93(15, 'CODE_93'),
  dataBar(16, 'DATA_BAR'),
  dataBarExpanded(17, 'DATA_BAR_EXPANDED'),
  dataBarLimited(18, 'DATA_BAR_LIMITED'),
  maxiCode(19, 'MAXI_CODE'),
  microPdf417(20, 'MICRO_PDF_417'),
  compactPdf417(21, 'COMPACT_PDF_417'),
  telepen(22, 'TELEPEN'),
  dxFilmEdge(23, 'DX_FILM_EDGE');

  const BarcodeFormat(this.cValue, this.displayName);

  /// Integer constant matching `CBarcodeFormat` in `src/zxing_ffi_bridge.h`.
  final int cValue;

  /// Human-readable format name.
  final String displayName;

  /// Resolves a [BarcodeFormat] from its native C enum integer.
  static BarcodeFormat fromCValue(int value) {
    for (final format in BarcodeFormat.values) {
      if (format.cValue == value) {
        return format;
      }
    }
    return BarcodeFormat.unknown;
  }

  /// Resolves a [BarcodeFormat] from a Web `BarcodeDetector` or `zxing-wasm` string.
  static BarcodeFormat fromString(String raw) {
    final normalized =
        raw.trim().toLowerCase().replaceAll(RegExp(r'[\s_\-/]'), '');
    switch (normalized) {
      case 'qrcode':
      case 'qrcodemodel1':
      case 'qrcodemodel2':
        return BarcodeFormat.qrCode;
      case 'microqrcode':
        return BarcodeFormat.microQrCode;
      case 'rmqrcode':
        return BarcodeFormat.rmqrCode;
      case 'datamatrix':
        return BarcodeFormat.dataMatrix;
      case 'aztec':
      case 'azteccode':
      case 'aztecrune':
        return BarcodeFormat.aztec;
      case 'pdf417':
        return BarcodeFormat.pdf417;
      case 'compactpdf417':
        return BarcodeFormat.compactPdf417;
      case 'micropdf417':
        return BarcodeFormat.microPdf417;
      case 'code128':
        return BarcodeFormat.code128;
      case 'code39':
      case 'code39std':
      case 'code39standard':
      case 'code39ext':
      case 'code39extended':
      case 'code32':
      case 'pzn':
        return BarcodeFormat.code39;
      case 'code93':
        return BarcodeFormat.code93;
      case 'ean13':
      case 'isbn':
        return BarcodeFormat.ean13;
      case 'ean8':
        return BarcodeFormat.ean8;
      case 'upca':
        return BarcodeFormat.upcA;
      case 'upce':
        return BarcodeFormat.upcE;
      case 'itf':
      case 'itf14':
        return BarcodeFormat.itf;
      case 'codabar':
        return BarcodeFormat.codabar;
      case 'databar':
      case 'databaromni':
      case 'databarstk':
      case 'databarstacked':
      case 'databarstkomni':
        return BarcodeFormat.dataBar;
      case 'databarexp':
      case 'databarexpanded':
      case 'databarexpstk':
      case 'databarexpandedstacked':
        return BarcodeFormat.dataBarExpanded;
      case 'databarltd':
      case 'databarlimited':
        return BarcodeFormat.dataBarLimited;
      case 'maxicode':
        return BarcodeFormat.maxiCode;
      case 'telepen':
      case 'telepenalpha':
      case 'telepennumeric':
        return BarcodeFormat.telepen;
      case 'dxfilmedge':
        return BarcodeFormat.dxFilmEdge;
      default:
        return BarcodeFormat.unknown;
    }
  }
}

/// Error Correction Capability (ECC) level for barcode generation.
enum BarcodeEccLevel {
  /// ~7% error recovery capability (Level L).
  low(0),

  /// ~15% error recovery capability (Level M).
  medium(1),

  /// ~25% error recovery capability (Level Q).
  quartile(2),

  /// ~30% error recovery capability (Level H).
  high(3);

  const BarcodeEccLevel(this.cValue);

  /// Integer value matching `CBarcodeEccLevel` in `src/zxing_ffi_bridge.h`.
  final int cValue;
}

/// Camera lens direction across mobile, desktop, and web platforms.
enum CameraFacing {
  /// Rear-facing environment camera (default on Android/iOS/mobile Web).
  back,

  /// Front-facing user camera (default on single-camera laptops/desktops).
  front,

  /// External USB / UVC webcam enumerated on macOS, Windows, Linux, or Web.
  external,
}

/// Hardware torch / flashlight state.
enum TorchState {
  /// Torch is supported and currently turned off.
  off,

  /// Torch is supported and currently turned on.
  on,

  /// Hardware torch is not available on the active camera (e.g. desktop webcam or front camera).
  unavailable,
}

/// Immutable result of decoding a single barcode / 2D code.
class BarcodeResult {
  /// Creates a [BarcodeResult] instance.
  const BarcodeResult({
    required this.text,
    required this.rawBytes,
    required this.cornerPoints,
    this.format = BarcodeFormat.qrCode,
    this.isValid = true,
    this.frameSize,
  });

  /// UTF-8 decoded text payload.
  final String text;

  /// Raw byte payload of the decoded symbol.
  final Uint8List rawBytes;

  /// Four localization corner points `[topLeft, topRight, bottomRight, bottomLeft]`
  /// in source image coordinates (or normalized `[0..1]` if [frameSize] is null).
  final List<Offset> cornerPoints;

  /// Recognized barcode symbology format.
  final BarcodeFormat format;

  /// Whether the symbol checksum and payload are valid.
  final bool isValid;

  /// Optional dimensions of the source image frame from which [cornerPoints] were measured.
  final Size? frameSize;

  /// Computes the geometric center of [cornerPoints] for drawing target anchor highlights.
  Offset get centerPoint {
    if (cornerPoints.isEmpty) {
      return Offset.zero;
    }
    double sumX = 0;
    double sumY = 0;
    for (final point in cornerPoints) {
      sumX += point.dx;
      sumY += point.dy;
    }
    return Offset(sumX / cornerPoints.length, sumY / cornerPoints.length);
  }

  /// Computes the axis-aligned bounding box enclosing [cornerPoints].
  Rect get boundingBox {
    if (cornerPoints.isEmpty) {
      return Rect.zero;
    }
    double minX = cornerPoints.first.dx;
    double maxX = cornerPoints.first.dx;
    double minY = cornerPoints.first.dy;
    double maxY = cornerPoints.first.dy;
    for (final point in cornerPoints.skip(1)) {
      if (point.dx < minX) minX = point.dx;
      if (point.dx > maxX) maxX = point.dx;
      if (point.dy < minY) minY = point.dy;
      if (point.dy > maxY) maxY = point.dy;
    }
    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  /// Maps [cornerPoints] from source camera frame coordinates (handling sensor
  /// rotation and `BoxFit.cover` cropping) into widget viewport coordinates.
  List<Offset> mapCornersToViewport({
    required Size viewportSize,
    int sensorOrientation = 0,
    bool isFrontCamera = false,
  }) {
    final Size srcSize = frameSize ?? viewportSize;
    if (srcSize.width <= 0 || srcSize.height <= 0 || cornerPoints.isEmpty) {
      return cornerPoints;
    }

    final bool swapDimensions =
        sensorOrientation == 90 || sensorOrientation == 270;
    final double orientedW = swapDimensions ? srcSize.height : srcSize.width;
    final double orientedH = swapDimensions ? srcSize.width : srcSize.height;

    final double scaleX = viewportSize.width / orientedW;
    final double scaleY = viewportSize.height / orientedH;
    final double scale = scaleX > scaleY ? scaleX : scaleY;

    final double scaledW = orientedW * scale;
    final double scaledH = orientedH * scale;
    final double offsetX = (viewportSize.width - scaledW) / 2.0;
    final double offsetY = (viewportSize.height - scaledH) / 2.0;

    return cornerPoints.map((pt) {
      double rx = pt.dx;
      double ry = pt.dy;
      switch (sensorOrientation % 360) {
        case 90:
          rx = srcSize.height - pt.dy;
          ry = pt.dx;
          break;
        case 180:
          rx = srcSize.width - pt.dx;
          ry = srcSize.height - pt.dy;
          break;
        case 270:
          rx = pt.dy;
          ry = srcSize.width - pt.dx;
          break;
        default:
          break;
      }
      if (isFrontCamera) {
        rx = orientedW - rx;
      }
      return Offset(rx * scale + offsetX, ry * scale + offsetY);
    }).toList(growable: false);
  }

  @override
  String toString() =>
      'BarcodeResult(text: "$text", format: ${format.displayName}, '
      'isValid: $isValid, cornerPoints: $cornerPoints)';
}

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
  bool get canSwitchCamera => availableCameraCount > 1;

  /// Creates a copy of this [ScannerState] with updated fields.
  ScannerState copyWith({
    bool? isInitialized,
    bool? isRunning,
    bool? isPaused,
    TorchState? torchState,
    CameraFacing? cameraFacing,
    int? availableCameraCount,
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
