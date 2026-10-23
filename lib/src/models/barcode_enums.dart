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
