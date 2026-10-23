import 'dart:async';
import 'package:flutter/material.dart';

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

/// Builder signature for customizing the prompt text (defaults to `"将二维码放入框内"`).
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
    this.hintText = '将二维码放入框内',
    this.torchOnLabel = '轻触关闭',
    this.torchOffLabel = '手电筒',
    this.galleryLabel = '相册',
    this.cutoutSize,
    this.cutoutBorderRadius = 16.0,
    this.maskColor = const Color(0x99000000),
    this.cornerColor = const Color(0xFF00E676),
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

  /// Callback invoked whenever one or more barcodes are recognized.
  final void Function(List<BarcodeResult> results)? onDetect;

  /// Default prompt displayed in the top region (`"将二维码放入框内"`).
  final String hintText;

  /// Label shown below the torch button when the flashlight is active.
  final String torchOnLabel;

  /// Label shown below the torch button when the flashlight is off.
  final String torchOffLabel;

  /// Label shown below the gallery picker button.
  final String galleryLabel;

  /// Optional fixed side length for the central square scan cutout.
  final double? cutoutSize;

  /// Corner radius of the central square scan cutout.
  final double cutoutBorderRadius;

  /// Color of the semi-transparent overlay outside the scan cutout.
  final Color maskColor;

  /// Color of the four L-shaped corner brackets around the scan cutout.
  final Color cornerColor;

  /// Color of the animated laser scan line.
  final Color scanLineColor;

  /// Duration of one top-to-bottom sweep of the laser scan line.
  final Duration scanLineDuration;

  /// Whether to render pulsing green anchor dots at `BarcodeResult.cornerPoints`.
  final bool showCornerHighlights;

  /// Whether to completely hide the torch button on desktop/devices without flash.
  final bool hideTorchWhenUnavailable;

  /// Custom builder to replace the semi-transparent mask and scan box.
  final XueHuaOverlayBuilder? overlayBuilder;

  /// Custom builder to replace the animated laser scan line.
  final XueHuaScanLineBuilder? scanLineBuilder;

  /// Custom builder to replace the top bar (back button, hint text, camera switch).
  final XueHuaTopBarBuilder? topBarBuilder;

  /// Custom builder to replace the `"将二维码放入框内"` hint text widget.
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

  void _attachController(XueHuaScannerController? externalController) {
    if (externalController != null) {
      _controller = externalController;
      _ownsController = false;
    } else {
      _controller = XueHuaScannerController();
      _ownsController = true;
    }

    _detectSubscription?.cancel();
    _detectSubscription =
        _controller.barcodesStream.listen((List<BarcodeResult> results) {
      widget.onDetect?.call(results);
    });

    if (!_controller.value.isInitialized && !_controller.value.isRunning) {
      unawaited(_controller.start());
    }
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
      }
      _attachController(widget.controller);
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
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _detectSubscription?.cancel();
    _scanLineController.dispose();
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  Future<void> _handleToggleTorch() async {
    final bool supported = _controller.value.hasTorch;
    if (!supported) {
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(
          content: Text('当前摄像头或桌面设备不支持手电筒闪光灯'),
          duration: Duration(seconds: 2),
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
    final List<BarcodeResult> results =
        await _controller.analyzeImageFromGallery();
    if (results.isEmpty && mounted) {
      await _showGalleryFallbackSheet();
    }
  }

  Future<void> _showGalleryFallbackSheet() async {
    if (!mounted) return;
    final TextEditingController textCtrl = TextEditingController(
      text: 'https://github.com/Matkurban/xue_hua_barcode_scanner',
    );
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1A1D24),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext sheetContext) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            MediaQuery.of(sheetContext).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const Text(
                '相册图片条码/二维码识别 (模拟器/桌面端快速验证)',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '生成一张内存条码图片并立即通过 zxing-cpp 解码识别：',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: textCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: '条码/二维码内容',
                  labelStyle: const TextStyle(color: Colors.white70),
                  filled: true,
                  fillColor: Colors.white10,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF00C853),
                  foregroundColor: Colors.black,
                ),
                onPressed: () async {
                  final String payload = textCtrl.text.trim();
                  Navigator.of(sheetContext).pop();
                  if (payload.isNotEmpty) {
                    await _controller.simulateBarcodeDetection(payload);
                  }
                },
                icon: const Icon(Icons.qr_code_2),
                label: const Text('生成图片并解码识别'),
              ),
            ],
          ),
        );
      },
    );
    textCtrl.dispose();
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
                _buildCameraPreview(context, state, viewportSize),

                if (widget.overlayBuilder != null)
                  widget.overlayBuilder!(context, scanWindow, state)
                else
                  XueHuaScannerOverlay(
                    scanWindow: scanWindow,
                    maskColor: widget.maskColor,
                    cornerColor: widget.cornerColor,
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
                    lineColor: widget.scanLineColor,
                  ),

                if (widget.showCornerHighlights &&
                    state.latestResults.isNotEmpty)
                  XueHuaCornerAnchorHighlight(
                    results: state.latestResults,
                    viewportSize: viewportSize,
                    sensorOrientation: state.sensorOrientation,
                    isFrontCamera: state.cameraFacing == CameraFacing.front,
                    anchorColor: widget.cornerColor,
                  ),

                SafeArea(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      _buildTopSection(context, state),
                      _buildBottomSection(context, state),
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

  Widget _buildCameraPreview(
    BuildContext context,
    ScannerState state,
    Size viewportSize,
  ) {
    if (widget.cameraPreviewBuilder != null) {
      return widget.cameraPreviewBuilder!(context, state);
    }

    if (_controller.isWeb && state.webViewType != null) {
      return SizedBox.expand(
        child: HtmlElementView(viewType: state.webViewType!),
      );
    }

    if (state.textureId != null) {
      final double previewAspect = state.previewSize.height > 0
          ? state.previewSize.width / state.previewSize.height
          : (16.0 / 9.0);
      final bool isPortrait = viewportSize.height > viewportSize.width;
      final double effectiveAspect =
          isPortrait ? (1.0 / previewAspect) : previewAspect;

      return ClipRect(
        child: OverflowBox(
          alignment: Alignment.center,
          child: FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: viewportSize.width,
              height: viewportSize.width / effectiveAspect,
              child: Texture(textureId: state.textureId!),
            ),
          ),
        ),
      );
    }

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
          padding: const EdgeInsets.only(top: 260),
          child: Text(
            state.cameraFacing == CameraFacing.front
                ? '前置相机取景中 (${XueHuaBarcodeScanner.engineVersion})'
                : '后置相机取景中 (${XueHuaBarcodeScanner.engineVersion})',
            style: const TextStyle(
              color: Color(0x66FFFFFF),
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopSection(BuildContext context, ScannerState state) {
    final VoidCallback onBack = () => Navigator.of(context).maybePop();
    if (widget.topBarBuilder != null) {
      return widget.topBarBuilder!(
        context,
        state,
        onBack,
        _handleSwitchCamera,
      );
    }

    final Widget hintWidget = widget.hintTextBuilder != null
        ? widget.hintTextBuilder!(context, state)
        : Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.14),
              ),
            ),
            child: Text(
              widget.hintText,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
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
            tooltip: '返回',
            onPressed: onBack,
          ),
          Expanded(
            child: Center(child: hintWidget),
          ),
          _CircleGlassIconButton(
            key: const ValueKey<String>('xh_scanner_switch_camera_button'),
            icon: Icons.cameraswitch_rounded,
            tooltip: '切换前后摄像头',
            onPressed: _handleSwitchCamera,
          ),
        ],
      ),
    );
  }

  Widget _buildBottomSection(BuildContext context, ScannerState state) {
    if (widget.bottomBarBuilder != null) {
      return widget.bottomBarBuilder!(
        context,
        state,
        _handleToggleTorch,
        _handlePickGallery,
      );
    }

    final Widget torchButton = widget.torchButtonBuilder != null
        ? widget.torchButtonBuilder!(context, state, _handleToggleTorch)
        : _ScannerBottomActionButton(
            key: const ValueKey<String>('xh_scanner_torch_button'),
            icon: state.isTorchOn
                ? Icons.flashlight_on_rounded
                : Icons.flashlight_off_rounded,
            label: state.isTorchOn ? widget.torchOnLabel : widget.torchOffLabel,
            isActive: state.isTorchOn,
            isEnabled: state.hasTorch,
            activeColor: widget.cornerColor,
            onTap: _handleToggleTorch,
          );

    final Widget galleryButton = widget.galleryButtonBuilder != null
        ? widget.galleryButtonBuilder!(context, state, _handlePickGallery)
        : _ScannerBottomActionButton(
            key: const ValueKey<String>('xh_scanner_gallery_button'),
            icon: Icons.photo_library_rounded,
            label: widget.galleryLabel,
            isActive: false,
            isEnabled: true,
            activeColor: widget.cornerColor,
            onTap: _handlePickGallery,
          );

    final bool hideTorch =
        widget.hideTorchWhenUnavailable && !state.hasTorch;

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
/// with 100% customizable UI builders and `XueHuaScannerController` support.
class XueHuaBarcodeScannerPage extends StatelessWidget {
  /// Creates a [XueHuaBarcodeScannerPage].
  const XueHuaBarcodeScannerPage({
    super.key,
    this.controller,
    this.onDetect,
    this.autoPopOnDetect = false,
    this.hintText = '将二维码放入框内',
    this.torchOnLabel = '轻触关闭',
    this.torchOffLabel = '手电筒',
    this.galleryLabel = '相册',
    this.cutoutSize,
    this.cutoutBorderRadius = 16.0,
    this.maskColor = const Color(0x99000000),
    this.cornerColor = const Color(0xFF00E676),
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

  /// Callback invoked when one or more barcodes are detected.
  final void Function(List<BarcodeResult> results)? onDetect;

  /// If `true`, automatically pops this route with `List<BarcodeResult>` on first detection.
  final bool autoPopOnDetect;

  /// Prompt text displayed in the top region (defaults to `"将二维码放入框内"`).
  final String hintText;

  /// Label displayed when the flashlight is active.
  final String torchOnLabel;

  /// Label displayed when the flashlight is off.
  final String torchOffLabel;

  /// Label displayed below the gallery picker button.
  final String galleryLabel;

  /// Optional custom side length of the central square cutout.
  final double? cutoutSize;

  /// Corner radius of the central square cutout.
  final double cutoutBorderRadius;

  /// Semi-transparent background mask color.
  final Color maskColor;

  /// Highlight color of the four corner brackets.
  final Color cornerColor;

  /// Color of the animated green laser scan line.
  final Color scanLineColor;

  /// Sweep duration of the scan line animation.
  final Duration scanLineDuration;

  /// Whether to draw green anchor dots at detected `cornerPoints`.
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
        hintText: hintText,
        torchOnLabel: torchOnLabel,
        torchOffLabel: torchOffLabel,
        galleryLabel: galleryLabel,
        cutoutSize: cutoutSize,
        cutoutBorderRadius: cutoutBorderRadius,
        maskColor: maskColor,
        cornerColor: cornerColor,
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
