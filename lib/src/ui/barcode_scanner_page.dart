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
/// with 100% customizable UI builders, multi-barcode freeze & tap selection,
/// custom positioned marker widgets ([barcodeMarkerBuilder]), localized [texts],
/// [validator] support, and [ScannerController] integration.
class BarcodeScannerPage extends StatelessWidget {
  /// Creates a [BarcodeScannerPage].
  const BarcodeScannerPage({
    super.key,
    this.controller,
    this.onDetect,
    this.onBarcodeSelected,
    this.validator,
    this.autoPopOnDetect = false,
    this.texts = const ScannerTexts(),
    this.showCutoutOverlay = false,
    this.showScanCutout = false,
    this.cutoutSize,
    this.cutoutBorderRadius = 20.0,
    this.maskColor = const Color(0x99000000),
    this.cornerColor = const Color(0xFF07C160),
    this.errorColor = const Color(0xFFFF5252),
    this.scanLineColor = const Color(0xFF07C160),
    this.scanLineDuration = const Duration(milliseconds: 2400),
    this.showCornerHighlights = true,
    this.enableMultiBarcodeSelection = true,
    this.hideBottomBarOnMultiSelect = true,
    this.multiSelectMaskColor = const Color(0x88000000),
    this.markerAlignment = BarcodeMarkerAlignment.center,
    this.hideTorchWhenUnavailable = false,
    this.overlayBuilder,
    this.scanLineBuilder,
    this.topBarBuilder,
    this.hintTextBuilder,
    this.bottomBarBuilder,
    this.torchButtonBuilder,
    this.galleryButtonBuilder,
    this.barcodeMarkerBuilder,
    this.multiBarcodeOverlayBuilder,
    this.permissionDeniedBuilder,
    this.cameraPreviewBuilder,
  });

  /// Optional external [ScannerController].
  final ScannerController? controller;

  /// Callback invoked when one or more valid barcodes are detected
  /// (or when the user taps a barcode marker in multi-barcode selection mode).
  final void Function(List<BarcodeResult> results)? onDetect;

  /// Callback invoked when a single barcode is selected (either by tapping its
  /// marker in multi-barcode selection mode or upon single-barcode detection).
  final void Function(BarcodeResult result)? onBarcodeSelected;

  /// Optional validation predicate to check whether a decoded [BarcodeResult]
  /// is acceptable. When returning `false`, the overlay turns red
  /// ([errorColor]) and [ScannerTexts.invalidBarcodeText] is shown.
  final BarcodeValidator? validator;

  /// If `true`, automatically pops this route with `List<BarcodeResult>` on first valid detection
  /// (or after the user selects a barcode in multi-barcode mode).
  final bool autoPopOnDetect;

  /// Localized text strings for all UI elements in the scanner page.
  final ScannerTexts texts;

  /// Whether to render a central square cutout box (`true`) instead of the
  /// default full-screen open viewfinder (`false`).
  final bool showCutoutOverlay;

  /// Alias for [showCutoutOverlay] to toggle the central square cutout box.
  final bool showScanCutout;

  /// Optional custom side length of the central square cutout.
  final double? cutoutSize;

  /// Corner radius of the central square cutout.
  final double cutoutBorderRadius;

  /// Semi-transparent background mask color when cutout mode is enabled.
  final Color maskColor;

  /// Highlight color of the target markers and corner brackets (defaults to `#07C160`).
  final Color cornerColor;

  /// Red highlight color used when a barcode fails validation.
  final Color errorColor;

  /// Color of the animated optical mesh scan line (defaults to `#07C160`).
  final Color scanLineColor;

  /// Sweep duration of the scan line animation.
  final Duration scanLineDuration;

  /// Whether to draw interactive target anchor markers at detected barcode coordinates.
  final bool showCornerHighlights;

  /// Whether to automatically freeze the camera preview when 2 or more valid
  /// barcodes are detected and let the user manually tap one to select.
  final bool enableMultiBarcodeSelection;

  /// Whether to hide the bottom Torch & Gallery action buttons while paused in
  /// multi-barcode selection mode.
  final bool hideBottomBarOnMultiSelect;

  /// Semi-transparent backdrop mask color shown over the frozen frame in
  /// multi-barcode selection mode.
  final Color multiSelectMaskColor;

  /// Alignment mode for positioning default or custom barcode marker widgets.
  final BarcodeMarkerAlignment markerAlignment;

  /// Whether to hide the torch button when hardware flash is unavailable.
  final bool hideTorchWhenUnavailable;

  /// Custom builder for the mask & scan box.
  final OverlayBuilder? overlayBuilder;

  /// Custom builder for the scan line animation.
  final ScanLineBuilder? scanLineBuilder;

  /// Custom builder for the top bar.
  final TopBarBuilder? topBarBuilder;

  /// Custom builder for the hint text.
  final HintTextBuilder? hintTextBuilder;

  /// Custom builder for the bottom bar.
  final BottomBarBuilder? bottomBarBuilder;

  /// Custom builder for the torch button.
  final TorchButtonBuilder? torchButtonBuilder;

  /// Custom builder for the gallery button.
  final GalleryButtonBuilder? galleryButtonBuilder;

  /// Custom builder to render any widget at each detected barcode's exact
  /// viewport position (`info.center`, `info.boundingBox`, `info.cornerPoints`).
  final BarcodeMarkerBuilder? barcodeMarkerBuilder;

  /// Custom builder to replace the entire multi-barcode selection overlay.
  final MultiBarcodeOverlayBuilder? multiBarcodeOverlayBuilder;

  /// Custom builder for the camera permission-denied recovery view.
  final PermissionDeniedBuilder? permissionDeniedBuilder;

  /// Custom builder for overriding the camera preview widget.
  final Widget Function(BuildContext context, ScannerState state)?
  cameraPreviewBuilder;

  @override
  Widget build(BuildContext context) {
    bool hasPopped = false;
    return Scaffold(
      backgroundColor: Colors.black,
      body: ScannerView(
        controller: controller,
        validator: validator,
        texts: texts,
        showCutoutOverlay: showCutoutOverlay,
        showScanCutout: showScanCutout,
        cutoutSize: cutoutSize,
        cutoutBorderRadius: cutoutBorderRadius,
        maskColor: maskColor,
        cornerColor: cornerColor,
        errorColor: errorColor,
        scanLineColor: scanLineColor,
        scanLineDuration: scanLineDuration,
        showCornerHighlights: showCornerHighlights,
        enableMultiBarcodeSelection: enableMultiBarcodeSelection,
        hideBottomBarOnMultiSelect: hideBottomBarOnMultiSelect,
        multiSelectMaskColor: multiSelectMaskColor,
        markerAlignment: markerAlignment,
        hideTorchWhenUnavailable: hideTorchWhenUnavailable,
        overlayBuilder: overlayBuilder,
        scanLineBuilder: scanLineBuilder,
        topBarBuilder: topBarBuilder,
        hintTextBuilder: hintTextBuilder,
        bottomBarBuilder: bottomBarBuilder,
        torchButtonBuilder: torchButtonBuilder,
        galleryButtonBuilder: galleryButtonBuilder,
        barcodeMarkerBuilder: barcodeMarkerBuilder,
        multiBarcodeOverlayBuilder: multiBarcodeOverlayBuilder,
        permissionDeniedBuilder: permissionDeniedBuilder,
        cameraPreviewBuilder: cameraPreviewBuilder,
        onBarcodeSelected: onBarcodeSelected,
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
