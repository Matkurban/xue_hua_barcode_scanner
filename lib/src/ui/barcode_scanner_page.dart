import 'package:material_ui/material_ui.dart';

import '../controller/scanner_controller.dart';
import '../models/barcode_result.dart';
import '../models/scanner_state.dart';
import '../models/scanner_texts.dart';
import 'scanner_builders.dart';
import 'scanner_view.dart';

export 'scanner_builders.dart';
export 'scanner_view.dart';

/// Full-screen ready-to-use Barcode & QR Code scanner route page (`Scaffold`)
/// with 100% customizable UI builders, localized [texts], [validator] support,
/// and [XueHuaScannerController] integration.
class XueHuaBarcodeScannerPage extends StatelessWidget {
  /// Creates a [XueHuaBarcodeScannerPage].
  const XueHuaBarcodeScannerPage({
    super.key,
    this.controller,
    this.onDetect,
    this.validator,
    this.autoPopOnDetect = false,
    this.texts = const XueHuaScannerTexts(),
    this.cutoutSize,
    this.cutoutBorderRadius = 16.0,
    this.maskColor = const Color(0x99000000),
    this.cornerColor = const Color(0xFF00E676),
    this.errorColor = const Color(0xFFFF5252),
    this.scanLineColor = const Color(0xFF00E676),
    this.scanLineDuration = const Duration(milliseconds: 2200),
    this.showCornerHighlights = true,
    this.hideTorchWhenUnavailable = false,
    this.overlayBuilder,
    this.scanLineBuilder,
    this.topBarBuilder,
    this.hintTextBuilder,
    this.bottomBarBuilder,
    this.torchButtonBuilder,
    this.galleryButtonBuilder,
    this.cameraPreviewBuilder,
  });

  /// Optional external [XueHuaScannerController].
  final XueHuaScannerController? controller;

  /// Callback invoked when one or more valid barcodes are detected.
  final void Function(List<BarcodeResult> results)? onDetect;

  /// Optional validation predicate to check whether a decoded [BarcodeResult]
  /// is acceptable. When returning `false`, the cutout border turns red
  /// ([errorColor]) and [XueHuaScannerTexts.invalidBarcodeText] is shown.
  final XueHuaBarcodeValidator? validator;

  /// If `true`, automatically pops this route with `List<BarcodeResult>` on first valid detection.
  final bool autoPopOnDetect;

  /// Localized text strings for all UI elements in the scanner page.
  final XueHuaScannerTexts texts;

  /// Optional custom side length of the central square cutout.
  final double? cutoutSize;

  /// Corner radius of the central square cutout.
  final double cutoutBorderRadius;

  /// Semi-transparent background mask color.
  final Color maskColor;

  /// Highlight color of the four corner brackets.
  final Color cornerColor;

  /// Red highlight color used when a barcode fails validation.
  final Color errorColor;

  /// Color of the animated green laser scan line.
  final Color scanLineColor;

  /// Sweep duration of the scan line animation.
  final Duration scanLineDuration;

  /// Whether to draw anchor dots at detected `cornerPoints`.
  final bool showCornerHighlights;

  /// Whether to hide the torch button when hardware flash is unavailable.
  final bool hideTorchWhenUnavailable;

  /// Custom builder for the mask & scan box.
  final XueHuaOverlayBuilder? overlayBuilder;

  /// Custom builder for the scan line animation.
  final XueHuaScanLineBuilder? scanLineBuilder;

  /// Custom builder for the top bar.
  final XueHuaTopBarBuilder? topBarBuilder;

  /// Custom builder for the hint text.
  final XueHuaHintTextBuilder? hintTextBuilder;

  /// Custom builder for the bottom bar.
  final XueHuaBottomBarBuilder? bottomBarBuilder;

  /// Custom builder for the torch button.
  final XueHuaTorchButtonBuilder? torchButtonBuilder;

  /// Custom builder for the gallery button.
  final XueHuaGalleryButtonBuilder? galleryButtonBuilder;

  /// Custom builder for overriding the camera preview widget.
  final Widget Function(BuildContext context, ScannerState state)?
  cameraPreviewBuilder;

  @override
  Widget build(BuildContext context) {
    bool hasPopped = false;
    return Scaffold(
      backgroundColor: Colors.black,
      body: XueHuaScannerView(
        controller: controller,
        validator: validator,
        texts: texts,
        cutoutSize: cutoutSize,
        cutoutBorderRadius: cutoutBorderRadius,
        maskColor: maskColor,
        cornerColor: cornerColor,
        errorColor: errorColor,
        scanLineColor: scanLineColor,
        scanLineDuration: scanLineDuration,
        showCornerHighlights: showCornerHighlights,
        hideTorchWhenUnavailable: hideTorchWhenUnavailable,
        overlayBuilder: overlayBuilder,
        scanLineBuilder: scanLineBuilder,
        topBarBuilder: topBarBuilder,
        hintTextBuilder: hintTextBuilder,
        bottomBarBuilder: bottomBarBuilder,
        torchButtonBuilder: torchButtonBuilder,
        galleryButtonBuilder: galleryButtonBuilder,
        cameraPreviewBuilder: cameraPreviewBuilder,
        onDetect: (List<BarcodeResult> results) {
          onDetect?.call(results);
          if (autoPopOnDetect && !hasPopped && results.isNotEmpty) {
            hasPopped = true;
            Navigator.of(context).maybePop(results);
          }
        },
      ),
    );
  }
}
