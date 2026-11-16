import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../models/barcode_result.dart';
import 'scanner_builders.dart';

/// Interactive layer that renders positioned barcode anchor widgets (WeChat-style
/// pulsing green dots with white arrows by default, or custom widgets via
/// [barcodeMarkerBuilder]) at each detected barcode's viewport coordinates.
typedef XueHuaBarcodeMarkersLayer = XueHuaCornerAnchorHighlight;

/// Renders interactive WeChat-style target anchor markers (or custom widgets
/// provided via [barcodeMarkerBuilder]) at each detected barcode's exact
/// viewport coordinates (`center`, `boundingBox`, `cornerPoints`).
class XueHuaCornerAnchorHighlight extends StatelessWidget {
  /// Creates a [XueHuaCornerAnchorHighlight].
  const XueHuaCornerAnchorHighlight({
    super.key,
    required this.results,
    required this.viewportSize,
    required this.sensorOrientation,
    required this.isFrontCamera,
    this.anchorColor = const Color(0xFF07C160),
    this.isMultiSelectMode = false,
    this.multiSelectMaskColor = const Color(0x88000000),
    this.markerAlignment = BarcodeMarkerAlignment.center,
    this.barcodeMarkerBuilder,
    this.onSelectBarcode,
  });

  /// Detected barcode results with `cornerPoints`.
  final List<BarcodeResult> results;

  /// Current viewport dimensions.
  final Size viewportSize;

  /// Active camera sensor orientation in degrees.
  final int sensorOrientation;

  /// Whether the active camera is front-facing (mirrored horizontally).
  final bool isFrontCamera;

  /// Fill color of the default WeChat target anchor badge (`#07C160`).
  final Color anchorColor;

  /// Whether the scanner has paused on multiple barcodes and is waiting for the
  /// user to tap a marker.
  final bool isMultiSelectMode;

  /// Semi-transparent dark backdrop color rendered behind markers in multi-select mode.
  final Color multiSelectMaskColor;

  /// How each marker widget is aligned relative to its barcode geometry.
  final BarcodeMarkerAlignment markerAlignment;

  /// Optional custom builder to render any widget at each barcode's exact location.
  final XueHuaBarcodeMarkerBuilder? barcodeMarkerBuilder;

  /// Callback invoked when the user taps a barcode marker.
  final ValueChanged<BarcodeResult>? onSelectBarcode;

  /// Computes the list of [BarcodeMarkerInfo] for [results] mapped into [viewportSize].
  static List<BarcodeMarkerInfo> computeMarkers({
    required List<BarcodeResult> results,
    required Size viewportSize,
    required int sensorOrientation,
    required bool isFrontCamera,
    required bool isMultiSelectMode,
  }) {
    final int total = results.length;
    return List<BarcodeMarkerInfo>.generate(total, (int index) {
      return results[index].toMarkerInfo(
        index: index,
        totalCount: total,
        viewportSize: viewportSize,
        sensorOrientation: sensorOrientation,
        isFrontCamera: isFrontCamera,
        isMultiSelectMode: isMultiSelectMode,
      );
    }, growable: false);
  }

  @override
  Widget build(BuildContext context) {
    if (results.isEmpty) {
      return const SizedBox.shrink();
    }

    final List<BarcodeMarkerInfo> markers = computeMarkers(
      results: results,
      viewportSize: viewportSize,
      sensorOrientation: sensorOrientation,
      isFrontCamera: isFrontCamera,
      isMultiSelectMode: isMultiSelectMode,
    );

    return RepaintBoundary(
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          if (isMultiSelectMode)
            IgnorePointer(
              child: ColoredBox(
                key: const ValueKey<String>('xh_scanner_multi_select_mask'),
                color: multiSelectMaskColor,
              ),
            ),
          CustomMultiChildLayout(
            delegate: _BarcodeMarkersLayoutDelegate(
              markers: markers,
              alignment: markerAlignment,
            ),
            children: <Widget>[
              for (final BarcodeMarkerInfo info in markers)
                LayoutId(
                  id: info.index,
                  child: KeyedSubtree(
                    key: ValueKey<String>(
                      'xh_scanner_barcode_marker_${info.index}',
                    ),
                    child: barcodeMarkerBuilder != null
                        ? barcodeMarkerBuilder!(
                            context,
                            info,
                            () => onSelectBarcode?.call(info.result),
                          )
                        : XueHuaWeChatBarcodeMarker(
                            info: info,
                            anchorColor: anchorColor,
                            onTap: onSelectBarcode != null
                                ? () => onSelectBarcode!(info.result)
                                : null,
                          ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BarcodeMarkersLayoutDelegate extends MultiChildLayoutDelegate {
  _BarcodeMarkersLayoutDelegate({
    required this.markers,
    required this.alignment,
  });

  final List<BarcodeMarkerInfo> markers;
  final BarcodeMarkerAlignment alignment;

  @override
  void performLayout(Size size) {
    for (final BarcodeMarkerInfo info in markers) {
      if (!hasChild(info.index)) continue;

      if (alignment == BarcodeMarkerAlignment.boundingBox &&
          info.boundingBox.width > 0 &&
          info.boundingBox.height > 0) {
        layoutChild(info.index, BoxConstraints.tight(info.boundingBox.size));
        positionChild(info.index, info.boundingBox.topLeft);
      } else {
        final Size childSize = layoutChild(
          info.index,
          BoxConstraints.loose(size),
        );
        final double maxX = math.max(4.0, size.width - childSize.width - 4.0);
        final double maxY = math.max(4.0, size.height - childSize.height - 4.0);
        final double dx = (info.center.dx - (childSize.width / 2.0)).clamp(
          4.0,
          maxX,
        );
        final double dy = (info.center.dy - (childSize.height / 2.0)).clamp(
          4.0,
          maxY,
        );
        positionChild(info.index, Offset(dx, dy));
      }
    }
  }

  @override
  bool shouldRelayout(covariant _BarcodeMarkersLayoutDelegate oldDelegate) {
    if (oldDelegate.alignment != alignment ||
        oldDelegate.markers.length != markers.length) {
      return true;
    }
    for (int i = 0; i < markers.length; i++) {
      final BarcodeMarkerInfo a = oldDelegate.markers[i];
      final BarcodeMarkerInfo b = markers[i];
      if (a.center != b.center ||
          a.boundingBox != b.boundingBox ||
          a.isMultiSelectMode != b.isMultiSelectMode ||
          a.result != b.result) {
        return true;
      }
    }
    return false;
  }
}

/// Default WeChat-style pulsing green circular barcode marker with a white
/// border, breathing halo ring, and white right-arrow icon (`→`) in multi-select mode.
class XueHuaWeChatBarcodeMarker extends StatefulWidget {
  /// Creates a [XueHuaWeChatBarcodeMarker].
  const XueHuaWeChatBarcodeMarker({
    super.key,
    required this.info,
    this.anchorColor = const Color(0xFF07C160),
    this.size = 42.0,
    this.onTap,
  });

  /// Mapped geometry and barcode payload for this marker.
  final BarcodeMarkerInfo info;

  /// Core fill color (defaults to WeChat green `#07C160`).
  final Color anchorColor;

  /// Diameter of the inner green circle in logical pixels.
  final double size;

  /// Callback invoked when the user taps this marker.
  final VoidCallback? onTap;

  @override
  State<XueHuaWeChatBarcodeMarker> createState() =>
      _XueHuaWeChatBarcodeMarkerState();
}

class _XueHuaWeChatBarcodeMarkerState extends State<XueHuaWeChatBarcodeMarker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  Widget build(BuildContext context) {
    final bool showArrow =
        widget.info.isMultiSelectMode || widget.info.totalCount >= 2;
    final double haloSpan = widget.size * 1.48;

    return Semantics(
      button: true,
      label: '选择二维码 ${widget.info.index + 1}: ${widget.info.result.text}',
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedScale(
          scale: _isPressed ? 0.88 : 1.0,
          duration: const Duration(milliseconds: 110),
          curve: Curves.easeOutCubic,
          child: SizedBox(
            width: haloSpan,
            height: haloSpan,
            child: Stack(
              alignment: Alignment.center,
              children: <Widget>[
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (BuildContext context, Widget? _) {
                    final double t = _pulseController.value;
                    final double currentDiameter =
                        widget.size + (haloSpan - widget.size) * t;
                    return Container(
                      width: currentDiameter,
                      height: currentDiameter,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: widget.anchorColor.withValues(
                          alpha: 0.38 * (1.0 - t * 0.65),
                        ),
                        border: Border.all(
                          color: Colors.white.withValues(
                            alpha: 0.35 * (1.0 - t * 0.7),
                          ),
                          width: 1.2,
                        ),
                      ),
                    );
                  },
                ),
                Container(
                  width: widget.size,
                  height: widget.size,
                  decoration: BoxDecoration(
                    color: widget.anchorColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2.5),
                    boxShadow: const <BoxShadow>[
                      BoxShadow(
                        color: Color(0x66000000),
                        blurRadius: 10,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Center(
                    child: showArrow
                        ? Icon(
                            Icons.arrow_forward_rounded,
                            color: Colors.white,
                            size: widget.size * 0.54,
                          )
                        : Container(
                            width: widget.size * 0.24,
                            height: widget.size * 0.24,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }
}
