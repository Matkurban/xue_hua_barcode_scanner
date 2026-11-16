import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../controller/scanner_controller.dart';
import '../models/barcode_enums.dart';
import '../models/barcode_result.dart';
import '../models/camera_input_source.dart';
import '../models/scanner_state.dart';
import '../models/scanner_texts.dart';
import 'corner_anchor_highlight.dart';
import 'scan_line_animation.dart';
import 'scanner_builders.dart';
import 'scanner_overlay.dart';
import 'widgets/scanner_bottom_bar.dart';
import 'widgets/scanner_camera_preview.dart';
import 'widgets/scanner_top_bar.dart';

/// Embeddable, 100% customizable Barcode & QR Code camera scanner view with
/// full-screen or cutout viewfinder and automatic multi-barcode freeze & tap selection.
class ScannerView extends StatefulWidget {
  /// Creates a [ScannerView].
  const ScannerView({
    super.key,
    this.controller,
    this.onDetect,
    this.onBarcodeSelected,
    this.validator,
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

  /// Optional external [ScannerController]. If omitted, an internal
  /// controller is created and disposed automatically.
  final ScannerController? controller;

  /// Callback invoked whenever one or more valid barcodes are recognized
  /// (or when the user taps a barcode marker in multi-barcode selection mode).
  final void Function(List<BarcodeResult> results)? onDetect;

  /// Callback invoked when a single barcode is selected (either by tapping its
  /// marker in multi-barcode selection mode or upon single-barcode detection).
  final void Function(BarcodeResult result)? onBarcodeSelected;

  /// Optional validation predicate to check whether a decoded [BarcodeResult]
  /// is acceptable. Returning `false` turns the scanner overlay red
  /// ([errorColor]) and displays [ScannerTexts.invalidBarcodeText].
  final BarcodeValidator? validator;

  /// Localized text strings for all UI elements in the scanner view.
  final ScannerTexts texts;

  /// Whether to display a central square cutout box with four corner brackets
  /// (`true`) instead of the default full-screen open viewfinder (`false`).
  final bool showCutoutOverlay;

  /// Alias for [showCutoutOverlay] to toggle the central square cutout box.
  final bool showScanCutout;

  /// Optional fixed side length for the central square scan cutout.
  final double? cutoutSize;

  /// Corner radius of the central square scan cutout.
  final double cutoutBorderRadius;

  /// Color of the semi-transparent overlay outside the scan cutout.
  final Color maskColor;

  /// Color of the target markers and corner brackets (defaults to `#07C160`).
  final Color cornerColor;

  /// Highlight color used when a barcode fails validation (`state.hasValidationError == true`).
  final Color errorColor;

  /// Color of the animated optical mesh scan line (defaults to `#07C160`).
  final Color scanLineColor;

  /// Duration of one top-to-bottom sweep of the scan line.
  final Duration scanLineDuration;

  /// Whether to render interactive target anchor markers at detected barcode coordinates.
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

  /// Whether to completely hide the torch button on desktop/devices without flash.
  final bool hideTorchWhenUnavailable;

  /// Custom builder to replace the semi-transparent mask and scan box.
  final OverlayBuilder? overlayBuilder;

  /// Custom builder to replace the animated laser scan line.
  final ScanLineBuilder? scanLineBuilder;

  /// Custom builder to replace the top bar (close/cancel button & camera switch).
  final TopBarBuilder? topBarBuilder;

  /// Custom builder to replace the hint text widget.
  final HintTextBuilder? hintTextBuilder;

  /// Custom builder to replace the entire bottom bar (torch & gallery buttons).
  final BottomBarBuilder? bottomBarBuilder;

  /// Custom builder to replace the torch toggle button.
  final TorchButtonBuilder? torchButtonBuilder;

  /// Custom builder to replace the gallery picker button.
  final GalleryButtonBuilder? galleryButtonBuilder;

  /// Custom builder to render any widget at each detected barcode's exact
  /// viewport position (`info.center`, `info.boundingBox`, `info.cornerPoints`).
  final BarcodeMarkerBuilder? barcodeMarkerBuilder;

  /// Custom builder to replace the entire multi-barcode selection overlay.
  final MultiBarcodeOverlayBuilder? multiBarcodeOverlayBuilder;

  /// Custom builder to replace the camera permission-denied recovery view.
  final PermissionDeniedBuilder? permissionDeniedBuilder;

  /// Optional custom builder for overriding the underlying camera preview layer.
  final Widget Function(BuildContext context, ScannerState state)?
  cameraPreviewBuilder;

  @override
  State<ScannerView> createState() => _ScannerViewState();
}

class _ScannerViewState extends State<ScannerView>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late ScannerController _controller;
  bool _ownsController = false;
  late final AnimationController _scanLineController;
  late final Animation<double> _scanLineAnimation;
  StreamSubscription<List<BarcodeResult>>? _detectSubscription;

  bool get _effectiveShowCutout =>
      widget.showCutoutOverlay ||
      widget.showScanCutout ||
      widget.cutoutSize != null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _scanLineController = AnimationController(
      vsync: this,
      duration: widget.scanLineDuration,
    )..repeat();

    _scanLineAnimation = CurvedAnimation(
      parent: _scanLineController,
      curve: Curves.easeInOutSine,
    );

    _attachController(widget.controller);
  }

  @override
  void didUpdateWidget(covariant ScannerView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scanLineDuration != widget.scanLineDuration) {
      _scanLineController.duration = widget.scanLineDuration;
      if (_scanLineController.isAnimating) {
        _scanLineController.repeat();
      }
    }
    if (oldWidget.controller != widget.controller) {
      _detectSubscription?.cancel();
      if (_ownsController) {
        _controller.dispose();
      } else {
        oldWidget.controller?.viewValidator = null;
        oldWidget.controller?.viewEnableMultiBarcodeSelection = null;
        oldWidget.controller?.viewOnBarcodeSelected = null;
      }
      _attachController(widget.controller);
    } else {
      _controller.viewValidator = widget.validator;
      _controller.viewEnableMultiBarcodeSelection =
          widget.enableMultiBarcodeSelection;
      _controller.viewOnBarcodeSelected = widget.onBarcodeSelected;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final ScannerState current = _controller.value;
    if (!current.isInitialized) return;
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      if (!current.isSelectingMultiBarcode) {
        unawaited(_controller.pause());
      }
    } else if (state == AppLifecycleState.resumed) {
      if (current.isPermissionDenied ||
          (current.hasCameraError && !current.isRunning)) {
        // Automatically retry starting the camera when returning from OS Settings.
        unawaited(_controller.retryCameraPermission());
      } else if (!current.isSelectingMultiBarcode) {
        unawaited(_controller.resume());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ScannerState>(
      valueListenable: _controller,
      builder: (BuildContext context, ScannerState state, Widget? _) {
        final bool shouldStopScanLine =
            state.isPaused ||
            state.isSelectingMultiBarcode ||
            state.isPermissionDenied ||
            state.hasCameraError;
        if (shouldStopScanLine && _scanLineController.isAnimating) {
          _scanLineController.stop();
        } else if (!shouldStopScanLine && !_scanLineController.isAnimating) {
          _scanLineController.repeat();
        }

        final bool isError = state.hasValidationError;
        final Color activeCornerColor = isError
            ? widget.errorColor
            : widget.cornerColor;
        final Color activeBorderColor = isError
            ? widget.errorColor.withValues(alpha: 0.85)
            : const Color(0x38FFFFFF);
        final double activeBorderWidth = isError ? 2.2 : 1.2;
        final Color activeScanLineColor = isError
            ? widget.errorColor
            : widget.scanLineColor;
        final bool showDefaultOverlay =
            !state.isPermissionDenied && !state.hasCameraError;
        final bool showCutout = _effectiveShowCutout;

        return LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final Size viewportSize = Size(
              constraints.maxWidth.isFinite ? constraints.maxWidth : 390,
              constraints.maxHeight.isFinite ? constraints.maxHeight : 844,
            );
            final Rect scanWindow = calculateScanWindowRect(
              viewportSize,
              customCutoutSize: widget.cutoutSize,
            );

            final Widget previewLayer = widget.cameraPreviewBuilder != null
                ? widget.cameraPreviewBuilder!(context, state)
                : ScannerCameraPreview(
                    isWeb: _controller.isWeb,
                    state: state,
                    texts: widget.texts,
                    scanWindow: scanWindow,
                    accentColor: widget.cornerColor,
                    permissionDeniedBuilder: widget.permissionDeniedBuilder,
                    onOpenSettings: _handleOpenSettings,
                    onRetryPermission: _handleRetryPermission,
                    onPickGallery: _handlePickGallery,
                  );

            final bool shouldRenderMarkers =
                state.latestResults.isNotEmpty &&
                (widget.showCornerHighlights ||
                    state.isSelectingMultiBarcode ||
                    widget.barcodeMarkerBuilder != null);

            return Stack(
              fit: StackFit.expand,
              children: <Widget>[
                if (state.isInitialized)
                  const SizedBox.shrink(
                    key: ValueKey<String>('xh_scanner_ready'),
                  ),
                if (state.isInitialized && !state.hasTorch)
                  const SizedBox.shrink(
                    key: ValueKey<String>('xh_scanner_no_torch'),
                  ),
                if (state.isInitialized && state.hasTorch)
                  const SizedBox.shrink(
                    key: ValueKey<String>('xh_scanner_has_torch'),
                  ),

                // When live or standby (no permission/hardware error), preview sits below overlay.
                if (showDefaultOverlay) previewLayer,

                if (widget.overlayBuilder != null)
                  widget.overlayBuilder!(context, scanWindow, state)
                else if (showDefaultOverlay)
                  ScannerOverlay(
                    scanWindow: scanWindow,
                    showCutout: showCutout,
                    hasValidationError: isError,
                    errorColor: widget.errorColor,
                    maskColor: widget.maskColor,
                    cornerColor: activeCornerColor,
                    borderColor: activeBorderColor,
                    borderStrokeWidth: activeBorderWidth,
                    borderRadius: widget.cutoutBorderRadius,
                  ),

                if (!state.isSelectingMultiBarcode) ...<Widget>[
                  if (widget.scanLineBuilder != null)
                    widget.scanLineBuilder!(
                      context,
                      _scanLineAnimation,
                      scanWindow,
                    )
                  else if (showDefaultOverlay && !state.isPaused)
                    ScanLineAnimation(
                      animation: _scanLineAnimation,
                      scanWindow: scanWindow,
                      lineColor: activeScanLineColor,
                      fullWidth: !showCutout,
                    ),
                ],

                // When permission is denied or camera has a hardware error, render the
                // interactive diagnostic surface above any custom overlay mask so its
                // buttons and guide remain 100% legible and clickable.
                if (!showDefaultOverlay) previewLayer,

                if (shouldRenderMarkers)
                  _buildBarcodeMarkersLayer(
                    context: context,
                    state: state,
                    viewportSize: viewportSize,
                    activeCornerColor: activeCornerColor,
                  ),

                SafeArea(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      ScannerTopBar(
                        state: state,
                        texts: widget.texts,
                        errorColor: widget.errorColor,
                        topBarBuilder: widget.topBarBuilder,
                        onSwitchCamera: _handleSwitchCamera,
                        onSelectCamera: _handleSelectCamera,
                        onCancelMultiSelect: _handleCancelMultiSelect,
                      ),
                      ScannerBottomBar(
                        state: state,
                        texts: widget.texts,
                        cornerColor: widget.cornerColor,
                        errorColor: widget.errorColor,
                        hideTorchWhenUnavailable:
                            widget.hideTorchWhenUnavailable,
                        hideBottomBarOnMultiSelect:
                            widget.hideBottomBarOnMultiSelect,
                        hintTextBuilder: widget.hintTextBuilder,
                        bottomBarBuilder: widget.bottomBarBuilder,
                        torchButtonBuilder: widget.torchButtonBuilder,
                        galleryButtonBuilder: widget.galleryButtonBuilder,
                        onToggleTorch: _handleToggleTorch,
                        onPickGallery: _handlePickGallery,
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildBarcodeMarkersLayer({
    required BuildContext context,
    required ScannerState state,
    required Size viewportSize,
    required Color activeCornerColor,
  }) {
    final bool isFront = state.cameraFacing == CameraFacing.front;
    if (state.isSelectingMultiBarcode &&
        widget.multiBarcodeOverlayBuilder != null) {
      final List<BarcodeMarkerInfo> markers =
          CornerAnchorHighlight.computeMarkers(
            results: state.latestResults,
            viewportSize: viewportSize,
            sensorOrientation: state.sensorOrientation,
            isFrontCamera: isFront,
            isMultiSelectMode: true,
          );
      return widget.multiBarcodeOverlayBuilder!(
        context,
        state,
        markers,
        _controller.selectBarcode,
        _handleCancelMultiSelect,
      );
    }

    return CornerAnchorHighlight(
      results: state.latestResults,
      viewportSize: viewportSize,
      sensorOrientation: state.sensorOrientation,
      isFrontCamera: isFront,
      anchorColor: activeCornerColor,
      isMultiSelectMode: state.isSelectingMultiBarcode,
      multiSelectMaskColor: widget.multiSelectMaskColor,
      markerAlignment: widget.markerAlignment,
      barcodeMarkerBuilder: widget.barcodeMarkerBuilder,
      onSelectBarcode: _controller.selectBarcode,
    );
  }

  void _attachController(ScannerController? externalController) {
    if (externalController != null) {
      _controller = externalController;
      _ownsController = false;
    } else {
      _controller = ScannerController(
        enableMultiBarcodeSelection: widget.enableMultiBarcodeSelection,
      );
      _ownsController = true;
    }
    _controller.viewValidator = widget.validator;
    _controller.viewEnableMultiBarcodeSelection =
        widget.enableMultiBarcodeSelection;
    _controller.viewOnBarcodeSelected = widget.onBarcodeSelected;

    _detectSubscription?.cancel();
    _detectSubscription = _controller.barcodesStream.listen((
      List<BarcodeResult> results,
    ) {
      widget.onDetect?.call(results);
    });

    if (!_controller.value.isInitialized && !_controller.value.isRunning) {
      unawaited(_controller.start());
    }
  }

  void _handleCancelMultiSelect() {
    unawaited(_controller.cancelMultiBarcodeSelection());
  }

  Future<void> _handleOpenSettings() async {
    final bool opened = await _controller.openAppSettings();
    if (!opened && mounted) {
      await _controller.retryCameraPermission();
    }
  }

  Future<void> _handleRetryPermission() async {
    await _controller.retryCameraPermission();
  }

  Future<void> _handleToggleTorch() async {
    if (!_controller.value.isInitialized) {
      return;
    }
    if (!_controller.value.hasTorch) {
      _showTorchUnsupportedMessage();
      return;
    }
    await _controller.toggleTorch();
    if (!mounted) {
      return;
    }
    if (!_controller.value.hasTorch) {
      _showTorchUnsupportedMessage();
    }
  }

  void _showTorchUnsupportedMessage() {
    if (!mounted) {
      return;
    }
    final ScaffoldMessengerState? messenger = ScaffoldMessenger.maybeOf(
      context,
    );
    messenger?.clearSnackBars();
    messenger?.showSnackBar(
      SnackBar(
        content: Text(
          widget.texts.torchUnsupportedMessage,
          key: const ValueKey<String>('xh_torch_unsupported_snackbar'),
        ),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _handleSwitchCamera() async {
    await _controller.switchCamera();
  }

  Future<void> _handleSelectCamera(CameraInputSource source) async {
    await _controller.selectCamera(source);
  }

  Future<void> _handlePickGallery() async {
    await _controller.analyzeImageFromGallery();
    if (!mounted) return;

    final GalleryScanStatus? status = _controller.value.lastGalleryScanStatus;
    if (status == GalleryScanStatus.noBarcodeFound) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(widget.texts.noBarcodeInImageText),
          backgroundColor: widget.errorColor.withValues(alpha: 0.9),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else if (status == GalleryScanStatus.invalidBarcode) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(widget.texts.invalidBarcodeText),
          backgroundColor: widget.errorColor.withValues(alpha: 0.9),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _detectSubscription?.cancel();
    _scanLineController.dispose();
    if (_ownsController) {
      _controller.dispose();
    } else {
      _controller.viewValidator = null;
      _controller.viewEnableMultiBarcodeSelection = null;
      _controller.viewOnBarcodeSelected = null;
    }
    super.dispose();
  }
}
