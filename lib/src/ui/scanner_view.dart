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

/// Embeddable, 100% customizable Barcode & QR Code camera scanner view.
class XueHuaScannerView extends StatefulWidget {
  /// Creates a [XueHuaScannerView].
  const XueHuaScannerView({
    super.key,
    this.controller,
    this.onDetect,
    this.validator,
    this.texts = const XueHuaScannerTexts(),
    this.cutoutSize,
    this.cutoutBorderRadius = 20.0,
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
    this.permissionDeniedBuilder,
    this.cameraPreviewBuilder,
  });

  /// Optional external [XueHuaScannerController]. If omitted, an internal
  /// controller is created and disposed automatically.
  final XueHuaScannerController? controller;

  /// Callback invoked whenever one or more valid barcodes are recognized.
  final void Function(List<BarcodeResult> results)? onDetect;

  /// Optional validation predicate to check whether a decoded [BarcodeResult]
  /// is acceptable. Returning `false` turns the scanner cutout border red
  /// ([errorColor]) and displays [XueHuaScannerTexts.invalidBarcodeText].
  final XueHuaBarcodeValidator? validator;

  /// Localized text strings for all UI elements in the scanner view.
  final XueHuaScannerTexts texts;

  /// Optional fixed side length for the central square scan cutout.
  final double? cutoutSize;

  /// Corner radius of the central square scan cutout.
  final double cutoutBorderRadius;

  /// Color of the semi-transparent overlay outside the scan cutout.
  final Color maskColor;

  /// Color of the four L-shaped corner brackets around the scan cutout.
  final Color cornerColor;

  /// Highlight color used for the scan cutout border and prompt when a barcode
  /// fails validation (`state.hasValidationError == true`).
  final Color errorColor;

  /// Color of the animated laser scan line.
  final Color scanLineColor;

  /// Duration of one top-to-bottom sweep of the laser scan line.
  final Duration scanLineDuration;

  /// Whether to render pulsing anchor dots at `BarcodeResult.cornerPoints`.
  final bool showCornerHighlights;

  /// Whether to completely hide the torch button on desktop/devices without flash.
  final bool hideTorchWhenUnavailable;

  /// Custom builder to replace the semi-transparent mask and scan box.
  final XueHuaOverlayBuilder? overlayBuilder;

  /// Custom builder to replace the animated laser scan line.
  final XueHuaScanLineBuilder? scanLineBuilder;

  /// Custom builder to replace the top bar (back button, hint text, camera switch).
  final XueHuaTopBarBuilder? topBarBuilder;

  /// Custom builder to replace the hint text widget.
  final XueHuaHintTextBuilder? hintTextBuilder;

  /// Custom builder to replace the entire bottom bar (torch & gallery buttons).
  final XueHuaBottomBarBuilder? bottomBarBuilder;

  /// Custom builder to replace the torch toggle button.
  final XueHuaTorchButtonBuilder? torchButtonBuilder;

  /// Custom builder to replace the gallery picker button.
  final XueHuaGalleryButtonBuilder? galleryButtonBuilder;

  /// Custom builder to replace the camera permission-denied recovery view.
  final XueHuaPermissionDeniedBuilder? permissionDeniedBuilder;

  /// Optional custom builder for overriding the underlying camera preview layer.
  final Widget Function(BuildContext context, ScannerState state)?
  cameraPreviewBuilder;

  @override
  State<XueHuaScannerView> createState() => _XueHuaScannerViewState();
}

class _XueHuaScannerViewState extends State<XueHuaScannerView>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late XueHuaScannerController _controller;
  bool _ownsController = false;
  late final AnimationController _scanLineController;
  late final Animation<double> _scanLineAnimation;
  StreamSubscription<List<BarcodeResult>>? _detectSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _scanLineController = AnimationController(
      vsync: this,
      duration: widget.scanLineDuration,
    )..repeat(reverse: true);

    _scanLineAnimation = CurvedAnimation(
      parent: _scanLineController,
      curve: Curves.easeInOut,
    );

    _attachController(widget.controller);
  }

  @override
  void didUpdateWidget(covariant XueHuaScannerView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scanLineDuration != widget.scanLineDuration) {
      _scanLineController.duration = widget.scanLineDuration;
      if (_scanLineController.isAnimating) {
        _scanLineController.repeat(reverse: true);
      }
    }
    if (oldWidget.controller != widget.controller) {
      _detectSubscription?.cancel();
      if (_ownsController) {
        _controller.dispose();
      } else {
        oldWidget.controller?.viewValidator = null;
      }
      _attachController(widget.controller);
    } else if (oldWidget.validator != widget.validator) {
      _controller.viewValidator = widget.validator;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final ScannerState current = _controller.value;
    if (!current.isInitialized) return;
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      unawaited(_controller.pause());
    } else if (state == AppLifecycleState.resumed) {
      if (current.isPermissionDenied ||
          (current.hasCameraError && !current.isRunning)) {
        // Automatically retry starting the camera when returning from OS Settings.
        unawaited(_controller.retryCameraPermission());
      } else {
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
            state.isPaused || state.isPermissionDenied || state.hasCameraError;
        if (shouldStopScanLine && _scanLineController.isAnimating) {
          _scanLineController.stop();
        } else if (!shouldStopScanLine && !_scanLineController.isAnimating) {
          _scanLineController.repeat(reverse: true);
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
        final bool showDefaultCutoutOverlay =
            !state.isPermissionDenied && !state.hasCameraError;

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
                if (showDefaultCutoutOverlay) previewLayer,

                if (widget.overlayBuilder != null)
                  widget.overlayBuilder!(context, scanWindow, state)
                else if (showDefaultCutoutOverlay)
                  XueHuaScannerOverlay(
                    scanWindow: scanWindow,
                    maskColor: widget.maskColor,
                    cornerColor: activeCornerColor,
                    borderColor: activeBorderColor,
                    borderStrokeWidth: activeBorderWidth,
                    borderRadius: widget.cutoutBorderRadius,
                  ),

                if (widget.scanLineBuilder != null)
                  widget.scanLineBuilder!(
                    context,
                    _scanLineAnimation,
                    scanWindow,
                  )
                else if (showDefaultCutoutOverlay)
                  XueHuaScanLineAnimation(
                    animation: _scanLineAnimation,
                    scanWindow: scanWindow,
                    lineColor: activeScanLineColor,
                  ),

                // When permission is denied or camera has a hardware error, render the
                // interactive diagnostic surface above any custom overlay mask so its
                // buttons and guide remain 100% legible and clickable.
                if (!showDefaultCutoutOverlay) previewLayer,

                if (widget.showCornerHighlights &&
                    state.latestResults.isNotEmpty)
                  XueHuaCornerAnchorHighlight(
                    results: state.latestResults,
                    viewportSize: viewportSize,
                    sensorOrientation: state.sensorOrientation,
                    isFrontCamera: state.cameraFacing == CameraFacing.front,
                    anchorColor: activeCornerColor,
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
                        hintTextBuilder: widget.hintTextBuilder,
                        onSwitchCamera: _handleSwitchCamera,
                        onSelectCamera: _handleSelectCamera,
                      ),
                      ScannerBottomBar(
                        state: state,
                        texts: widget.texts,
                        cornerColor: widget.cornerColor,
                        hideTorchWhenUnavailable:
                            widget.hideTorchWhenUnavailable,
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

  void _attachController(XueHuaScannerController? externalController) {
    if (externalController != null) {
      _controller = externalController;
      _ownsController = false;
    } else {
      _controller = XueHuaScannerController();
      _ownsController = true;
    }
    _controller.viewValidator = widget.validator;

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
    }
    super.dispose();
  }
}
