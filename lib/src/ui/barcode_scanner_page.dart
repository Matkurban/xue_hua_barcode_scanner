import 'dart:async';
import 'package:material_ui/material_ui.dart';

import '../controller/scanner_controller.dart';
import '../models/barcode_models.dart';
import 'scanner_overlay.dart';

/// Builder signature for customizing the semi-transparent mask and scan cutout box.
typedef XueHuaOverlayBuilder = Widget Function(
  BuildContext context,
  Rect scanWindow,
  ScannerState state,
);

/// Builder signature for customizing the animated scan line inside [scanWindow].
typedef XueHuaScanLineBuilder = Widget Function(
  BuildContext context,
  Animation<double> animation,
  Rect scanWindow,
);

/// Builder signature for customizing the top navigation bar (Back button,
/// centered hint title, and Front/Back camera switch button).
typedef XueHuaTopBarBuilder = Widget Function(
  BuildContext context,
  ScannerState state,
  VoidCallback onBack,
  VoidCallback onSwitchCamera,
);

/// Builder signature for customizing the prompt text.
typedef XueHuaHintTextBuilder = Widget Function(
  BuildContext context,
  ScannerState state,
);

/// Builder signature for customizing the entire bottom action bar.
typedef XueHuaBottomBarBuilder = Widget Function(
  BuildContext context,
  ScannerState state,
  VoidCallback onToggleTorch,
  VoidCallback onPickGallery,
);

/// Builder signature for customizing the Torch / Flashlight toggle button.
typedef XueHuaTorchButtonBuilder = Widget Function(
  BuildContext context,
  ScannerState state,
  VoidCallback onToggleTorch,
);

/// Builder signature for customizing the Gallery image picker button.
typedef XueHuaGalleryButtonBuilder = Widget Function(
  BuildContext context,
  ScannerState state,
  VoidCallback onPickGallery,
);

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
    if (!_controller.value.isInitialized) return;
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      unawaited(_controller.pause());
    } else if (state == AppLifecycleState.resumed) {
      unawaited(_controller.resume());
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ScannerState>(
      valueListenable: _controller,
      builder: (BuildContext context, ScannerState state, Widget? _) {
        if (state.isPaused && _scanLineController.isAnimating) {
          _scanLineController.stop();
        } else if (!state.isPaused && !_scanLineController.isAnimating) {
          _scanLineController.repeat(reverse: true);
        }

        final bool isError = state.hasValidationError;
        final Color activeCornerColor =
            isError ? widget.errorColor : widget.cornerColor;
        final Color activeBorderColor = isError
            ? widget.errorColor.withValues(alpha: 0.85)
            : const Color(0x38FFFFFF);
        final double activeBorderWidth = isError ? 2.2 : 1.2;
        final Color activeScanLineColor =
            isError ? widget.errorColor : widget.scanLineColor;

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

            return Stack(
              fit: StackFit.expand,
              children: <Widget>[
                if (widget.cameraPreviewBuilder != null)
                  widget.cameraPreviewBuilder!(context, state)
                else
                  _ScannerCameraPreview(
                    isWeb: _controller.isWeb,
                    state: state,
                    texts: widget.texts,
                  ),

                if (widget.overlayBuilder != null)
                  widget.overlayBuilder!(context, scanWindow, state)
                else
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
                else
                  XueHuaScanLineAnimation(
                    animation: _scanLineAnimation,
                    scanWindow: scanWindow,
                    lineColor: activeScanLineColor,
                  ),

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
                      _ScannerTopBar(
                        state: state,
                        texts: widget.texts,
                        errorColor: widget.errorColor,
                        topBarBuilder: widget.topBarBuilder,
                        hintTextBuilder: widget.hintTextBuilder,
                        onSwitchCamera: _handleSwitchCamera,
                      ),
                      _ScannerBottomBar(
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
    _detectSubscription =
        _controller.barcodesStream.listen((List<BarcodeResult> results) {
      widget.onDetect?.call(results);
    });

    if (!_controller.value.isInitialized && !_controller.value.isRunning) {
      unawaited(_controller.start());
    }
  }

  Future<void> _handleToggleTorch() async {
    final bool supported = _controller.value.hasTorch;
    if (!supported) {
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(widget.texts.torchUnsupportedMessage),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    await _controller.toggleTorch();
  }

  Future<void> _handleSwitchCamera() async {
    await _controller.switchCamera();
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

class _ScannerCameraPreview extends StatelessWidget {
  const _ScannerCameraPreview({
    required this.isWeb,
    required this.state,
    required this.texts,
  });

  final bool isWeb;
  final ScannerState state;
  final XueHuaScannerTexts texts;

  @override
  Widget build(BuildContext context) {
    if (isWeb && state.webViewType != null) {
      return SizedBox.expand(
        child: HtmlElementView(viewType: state.webViewType!),
      );
    }

    if (state.textureId != null) {
      final bool swapDimensions =
          state.sensorOrientation == 90 || state.sensorOrientation == 270;
      final double orientedWidth =
          swapDimensions ? state.previewSize.height : state.previewSize.width;
      final double orientedHeight =
          swapDimensions ? state.previewSize.width : state.previewSize.height;
      final double safeWidth = orientedWidth > 0 ? orientedWidth : 1280;
      final double safeHeight = orientedHeight > 0 ? orientedHeight : 720;

      return SizedBox.expand(
        child: ClipRect(
          child: FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: safeWidth,
              height: safeHeight,
              child: Texture(textureId: state.textureId!),
            ),
          ),
        ),
      );
    }

    final String statusText = state.errorMessage != null
        ? '${texts.cameraUnavailablePrefix}${state.errorMessage}'
        : (state.cameraFacing == CameraFacing.front
            ? '${texts.frontCameraPreviewText} (${XueHuaBarcodeScanner.engineVersion})'
            : '${texts.backCameraPreviewText} (${XueHuaBarcodeScanner.engineVersion})');

    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.center,
          radius: 1.1,
          colors: <Color>[
            Color(0xFF1E293B),
            Color(0xFF0F172A),
            Color(0xFF060911),
          ],
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.only(top: 260, left: 24, right: 24),
          child: Text(
            statusText,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0x99FFFFFF),
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}

class _ScannerTopBar extends StatelessWidget {
  const _ScannerTopBar({
    required this.state,
    required this.texts,
    required this.errorColor,
    required this.topBarBuilder,
    required this.hintTextBuilder,
    required this.onSwitchCamera,
  });

  final ScannerState state;
  final XueHuaScannerTexts texts;
  final Color errorColor;
  final XueHuaTopBarBuilder? topBarBuilder;
  final XueHuaHintTextBuilder? hintTextBuilder;
  final VoidCallback onSwitchCamera;

  @override
  Widget build(BuildContext context) {
    void onBack() {
      Navigator.of(context).maybePop();
    }

    if (topBarBuilder != null) {
      return topBarBuilder!(
        context,
        state,
        onBack,
        onSwitchCamera,
      );
    }

    final bool isError = state.hasValidationError;
    final String displayPrompt = isError
        ? (state.lastGalleryScanStatus == GalleryScanStatus.noBarcodeFound
            ? texts.noBarcodeInImageText
            : texts.invalidBarcodeText)
        : texts.hintText;

    final Widget hintWidget = hintTextBuilder != null
        ? hintTextBuilder!(context, state)
        : AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: isError
                  ? errorColor.withValues(alpha: 0.24)
                  : Colors.black.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isError
                    ? errorColor.withValues(alpha: 0.85)
                    : Colors.white.withValues(alpha: 0.14),
              ),
            ),
            child: Text(
              displayPrompt,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isError ? errorColor : Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.5,
              ),
            ),
          );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          _CircleGlassIconButton(
            key: const ValueKey<String>('xh_scanner_back_button'),
            icon: Icons.arrow_back_ios_new_rounded,
            tooltip: texts.backButtonTooltip,
            onPressed: onBack,
          ),
          Expanded(
            child: Center(child: hintWidget),
          ),
          _CircleGlassIconButton(
            key: const ValueKey<String>('xh_scanner_switch_camera_button'),
            icon: Icons.cameraswitch_rounded,
            tooltip: texts.switchCameraTooltip,
            onPressed: onSwitchCamera,
          ),
        ],
      ),
    );
  }
}

class _ScannerBottomBar extends StatelessWidget {
  const _ScannerBottomBar({
    required this.state,
    required this.texts,
    required this.cornerColor,
    required this.hideTorchWhenUnavailable,
    required this.bottomBarBuilder,
    required this.torchButtonBuilder,
    required this.galleryButtonBuilder,
    required this.onToggleTorch,
    required this.onPickGallery,
  });

  final ScannerState state;
  final XueHuaScannerTexts texts;
  final Color cornerColor;
  final bool hideTorchWhenUnavailable;
  final XueHuaBottomBarBuilder? bottomBarBuilder;
  final XueHuaTorchButtonBuilder? torchButtonBuilder;
  final XueHuaGalleryButtonBuilder? galleryButtonBuilder;
  final VoidCallback onToggleTorch;
  final VoidCallback onPickGallery;

  @override
  Widget build(BuildContext context) {
    if (bottomBarBuilder != null) {
      return bottomBarBuilder!(
        context,
        state,
        onToggleTorch,
        onPickGallery,
      );
    }

    final Widget torchButton = torchButtonBuilder != null
        ? torchButtonBuilder!(context, state, onToggleTorch)
        : _ScannerBottomActionButton(
            key: const ValueKey<String>('xh_scanner_torch_button'),
            icon: state.isTorchOn
                ? Icons.flashlight_on_rounded
                : Icons.flashlight_off_rounded,
            label: state.isTorchOn ? texts.torchOnLabel : texts.torchOffLabel,
            isActive: state.isTorchOn,
            isEnabled: state.hasTorch,
            activeColor: cornerColor,
            onTap: onToggleTorch,
          );

    final Widget galleryButton = galleryButtonBuilder != null
        ? galleryButtonBuilder!(context, state, onPickGallery)
        : _ScannerBottomActionButton(
            key: const ValueKey<String>('xh_scanner_gallery_button'),
            icon: Icons.photo_library_rounded,
            label: texts.galleryLabel,
            isActive: false,
            isEnabled: true,
            activeColor: cornerColor,
            onTap: onPickGallery,
          );

    final bool hideTorch = hideTorchWhenUnavailable && !state.hasTorch;

    return Padding(
      padding: const EdgeInsets.only(left: 48, right: 48, bottom: 36),
      child: Row(
        mainAxisAlignment: hideTorch
            ? MainAxisAlignment.center
            : MainAxisAlignment.spaceBetween,
        children: <Widget>[
          if (!hideTorch) torchButton,
          galleryButton,
        ],
      ),
    );
  }
}

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

class _CircleGlassIconButton extends StatelessWidget {
  const _CircleGlassIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.45),
      shape: CircleBorder(
        side: BorderSide(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: IconButton(
        tooltip: tooltip,
        icon: Icon(icon, color: Colors.white, size: 20),
        onPressed: onPressed,
      ),
    );
  }
}

class _ScannerBottomActionButton extends StatelessWidget {
  const _ScannerBottomActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.isActive,
    required this.isEnabled,
    required this.activeColor,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isActive;
  final bool isEnabled;
  final Color activeColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color bgColor = isActive
        ? activeColor.withValues(alpha: 0.25)
        : Colors.black.withValues(alpha: 0.50);
    final Color borderColor = isActive
        ? activeColor
        : Colors.white.withValues(alpha: isEnabled ? 0.24 : 0.10);
    final Color iconColor = isActive
        ? activeColor
        : Colors.white.withValues(alpha: isEnabled ? 0.95 : 0.40);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: bgColor,
              shape: BoxShape.circle,
              border: Border.all(color: borderColor, width: 1.5),
              boxShadow: isActive
                  ? <BoxShadow>[
                      BoxShadow(
                        color: activeColor.withValues(alpha: 0.45),
                        blurRadius: 14,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            child: Icon(icon, color: iconColor, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: isActive ? activeColor : iconColor,
              fontSize: 13,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}
