import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../models/qr_code_models.dart';

/// Calculates the centered square scan window [Rect] inside [viewportSize].
Rect calculateScanWindowRect(
  Size viewportSize, {
  double? customCutoutSize,
  double verticalOffset = -20.0,
}) {
  final double shortestSide = math.min(viewportSize.width, viewportSize.height);
  final double defaultSize = (shortestSide * 0.68).clamp(200.0, 320.0);
  final double boxSize =
      (customCutoutSize ?? defaultSize).clamp(140.0, shortestSide * 0.9);
  final double left = (viewportSize.width - boxSize) / 2.0;
  final double top =
      ((viewportSize.height - boxSize) / 2.0) + verticalOffset;
  return Rect.fromLTWH(left, top, boxSize, boxSize);
}

/// Full-screen semi-transparent dark mask with a rounded square cutout and
/// four highlighted corner borders (`CustomPainter`).
class XueHuaScannerOverlay extends StatelessWidget {
  /// Creates a [XueHuaScannerOverlay].
  const XueHuaScannerOverlay({
    super.key,
    required this.scanWindow,
    this.maskColor = const Color(0x99000000),
    this.borderColor = const Color(0x38FFFFFF),
    this.cornerColor = const Color(0xFF00E676),
    this.borderRadius = 16.0,
    this.cornerLength = 26.0,
    this.cornerStrokeWidth = 4.0,
    this.borderStrokeWidth = 1.2,
  });

  /// Centered square cutout rectangle in viewport coordinates.
  final Rect scanWindow;

  /// Semi-transparent background mask color outside [scanWindow].
  final Color maskColor;

  /// Thin frame outline color around [scanWindow].
  final Color borderColor;

  /// Highlight color for the four L-shaped corner brackets.
  final Color cornerColor;

  /// Corner radius of the cutout square.
  final double borderRadius;

  /// Length of each L-shaped corner arm in logical pixels.
  final double cornerLength;

  /// Stroke width of the four corner brackets.
  final double cornerStrokeWidth;

  /// Stroke width of the subtle full-box border.
  final double borderStrokeWidth;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          size: Size.infinite,
          painter: _XueHuaScannerOverlayPainter(
            scanWindow: scanWindow,
            maskColor: maskColor,
            borderColor: borderColor,
            cornerColor: cornerColor,
            borderRadius: borderRadius,
            cornerLength: cornerLength,
            cornerStrokeWidth: cornerStrokeWidth,
            borderStrokeWidth: borderStrokeWidth,
          ),
        ),
      ),
    );
  }
}

class _XueHuaScannerOverlayPainter extends CustomPainter {
  const _XueHuaScannerOverlayPainter({
    required this.scanWindow,
    required this.maskColor,
    required this.borderColor,
    required this.cornerColor,
    required this.borderRadius,
    required this.cornerLength,
    required this.cornerStrokeWidth,
    required this.borderStrokeWidth,
  });

  final Rect scanWindow;
  final Color maskColor;
  final Color borderColor;
  final Color cornerColor;
  final double borderRadius;
  final double cornerLength;
  final double cornerStrokeWidth;
  final double borderStrokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final Path fullScreenPath = Path()..addRect(Offset.zero & size);
    final RRect cutoutRRect = RRect.fromRectAndRadius(
      scanWindow,
      Radius.circular(borderRadius),
    );
    final Path cutoutPath = Path()..addRRect(cutoutRRect);

    // 1. Draw semi-transparent dark mask with central rounded square cutout.
    final Path maskPath = Path.combine(
      PathOperation.difference,
      fullScreenPath,
      cutoutPath,
    );
    final Paint maskPaint = Paint()
      ..color = maskColor
      ..style = PaintingStyle.fill;
    canvas.drawPath(maskPath, maskPaint);

    // 2. Draw subtle frame border around the cutout.
    if (borderStrokeWidth > 0) {
      final Paint borderPaint = Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = borderStrokeWidth;
      canvas.drawRRect(cutoutRRect, borderPaint);
    }

    // 3. Draw four glowing L-shaped corner brackets around the scan window.
    final Paint cornerPaint = Paint()
      ..color = cornerColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = cornerStrokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final double r = borderRadius.clamp(0.0, cornerLength);
    final double l = cornerLength;
    final double left = scanWindow.left;
    final double top = scanWindow.top;
    final double right = scanWindow.right;
    final double bottom = scanWindow.bottom;

    final Path cornersPath = Path()
      // Top-Left corner
      ..moveTo(left, top + l)
      ..lineTo(left, top + r)
      ..arcToPoint(
        Offset(left + r, top),
        radius: Radius.circular(r),
      )
      ..lineTo(left + l, top)
      // Top-Right corner
      ..moveTo(right - l, top)
      ..lineTo(right - r, top)
      ..arcToPoint(
        Offset(right, top + r),
        radius: Radius.circular(r),
      )
      ..lineTo(right, top + l)
      // Bottom-Right corner
      ..moveTo(right, bottom - l)
      ..lineTo(right, bottom - r)
      ..arcToPoint(
        Offset(right - r, bottom),
        radius: Radius.circular(r),
      )
      ..lineTo(right - l, bottom)
      // Bottom-Left corner
      ..moveTo(left + l, bottom)
      ..lineTo(left + r, bottom)
      ..arcToPoint(
        Offset(left, bottom - r),
        radius: Radius.circular(r),
      )
      ..lineTo(left, bottom - l);

    canvas.drawPath(cornersPath, cornerPaint);
  }

  @override
  bool shouldRepaint(covariant _XueHuaScannerOverlayPainter oldDelegate) {
    return oldDelegate.scanWindow != scanWindow ||
        oldDelegate.maskColor != maskColor ||
        oldDelegate.borderColor != borderColor ||
        oldDelegate.cornerColor != cornerColor ||
        oldDelegate.borderRadius != borderRadius ||
        oldDelegate.cornerLength != cornerLength ||
        oldDelegate.cornerStrokeWidth != cornerStrokeWidth;
  }
}

/// Smooth vertical back-and-forth green laser scan line with gradient glow
/// rendered inside [scanWindow].
class XueHuaScanLineAnimation extends StatelessWidget {
  /// Creates a [XueHuaScanLineAnimation].
  const XueHuaScanLineAnimation({
    super.key,
    required this.animation,
    required this.scanWindow,
    this.lineColor = const Color(0xFF00E676),
    this.lineHeight = 3.0,
    this.glowHeight = 36.0,
    this.horizontalPadding = 12.0,
  });

  /// Driving animation (`0.0` -> `1.0`).
  final Animation<double> animation;

  /// Bounds of the central scan cutout.
  final Rect scanWindow;

  /// Primary laser color (defaults to vibrant emerald green `#00E676`).
  final Color lineColor;

  /// Core thickness of the laser line.
  final double lineHeight;

  /// Height of the trailing gradient glow halo.
  final double glowHeight;

  /// Horizontal inset from the left and right edges of [scanWindow].
  final double horizontalPadding;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: animation,
        builder: (BuildContext context, Widget? _) {
          final double verticalMargin = 12.0;
          final double travelRange = math.max(
            0.0,
            scanWindow.height - (verticalMargin * 2) - lineHeight,
          );
          final double currentY =
              scanWindow.top + verticalMargin + (travelRange * animation.value);

          return Stack(
            children: <Widget>[
              Positioned(
                left: scanWindow.left + horizontalPadding,
                width: math.max(0.0, scanWindow.width - horizontalPadding * 2),
                top: currentY - (glowHeight / 2),
                height: glowHeight,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: <Color>[
                        lineColor.withValues(alpha: 0.0),
                        lineColor.withValues(alpha: 0.28),
                        lineColor.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: scanWindow.left + horizontalPadding,
                width: math.max(0.0, scanWindow.width - horizontalPadding * 2),
                top: currentY,
                height: lineHeight,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(lineHeight),
                    gradient: LinearGradient(
                      colors: <Color>[
                        lineColor.withValues(alpha: 0.05),
                        lineColor,
                        const Color(0xFFB9F6CA),
                        lineColor,
                        lineColor.withValues(alpha: 0.05),
                      ],
                      stops: const <double>[0.0, 0.2, 0.5, 0.8, 1.0],
                    ),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: lineColor.withValues(alpha: 0.75),
                        blurRadius: 10,
                        spreadRadius: 1.5,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Draws pulsing green anchor points and corner polygons over detected QR codes.
class XueHuaCornerAnchorHighlight extends StatefulWidget {
  /// Creates a [XueHuaCornerAnchorHighlight].
  const XueHuaCornerAnchorHighlight({
    super.key,
    required this.results,
    required this.viewportSize,
    required this.sensorOrientation,
    required this.isFrontCamera,
    this.anchorColor = const Color(0xFF00E676),
  });

  /// Detected QR code results with `cornerPoints`.
  final List<QrCodeResult> results;

  /// Current viewport dimensions.
  final Size viewportSize;

  /// Active camera sensor orientation in degrees.
  final int sensorOrientation;

  /// Whether the active camera is front-facing (mirrored horizontally).
  final bool isFrontCamera;

  /// Fill color of the target anchor badge.
  final Color anchorColor;

  @override
  State<XueHuaCornerAnchorHighlight> createState() =>
      _XueHuaCornerAnchorHighlightState();
}

class _XueHuaCornerAnchorHighlightState
    extends State<XueHuaCornerAnchorHighlight>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.results.isEmpty) {
      return const SizedBox.shrink();
    }
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _pulseController,
        builder: (BuildContext context, Widget? _) {
          return CustomPaint(
            size: widget.viewportSize,
            painter: _CornerAnchorPainter(
              results: widget.results,
              viewportSize: widget.viewportSize,
              sensorOrientation: widget.sensorOrientation,
              isFrontCamera: widget.isFrontCamera,
              anchorColor: widget.anchorColor,
              pulseValue: _pulseController.value,
            ),
          );
        },
      ),
    );
  }
}

class _CornerAnchorPainter extends CustomPainter {
  const _CornerAnchorPainter({
    required this.results,
    required this.viewportSize,
    required this.sensorOrientation,
    required this.isFrontCamera,
    required this.anchorColor,
    required this.pulseValue,
  });

  final List<QrCodeResult> results;
  final Size viewportSize;
  final int sensorOrientation;
  final bool isFrontCamera;
  final Color anchorColor;
  final double pulseValue;

  @override
  void paint(Canvas canvas, Size size) {
    for (final QrCodeResult result in results) {
      final List<Offset> mapped = result.mapCornersToViewport(
        viewportSize: viewportSize,
        sensorOrientation: sensorOrientation,
        isFrontCamera: isFrontCamera,
      );
      if (mapped.isEmpty) continue;

      if (mapped.length >= 4) {
        final Path poly = Path()..moveTo(mapped[0].dx, mapped[0].dy);
        for (int i = 1; i < mapped.length; i++) {
          poly.lineTo(mapped[i].dx, mapped[i].dy);
        }
        poly.close();

        canvas.drawPath(
          poly,
          Paint()
            ..color = anchorColor.withValues(alpha: 0.18)
            ..style = PaintingStyle.fill,
        );
        canvas.drawPath(
          poly,
          Paint()
            ..color = anchorColor
            ..strokeWidth = 2.5
            ..style = PaintingStyle.stroke,
        );
      }

      // Compute center point of mapped corners for the green target dot.
      double sumX = 0;
      double sumY = 0;
      for (final Offset pt in mapped) {
        sumX += pt.dx;
        sumY += pt.dy;
      }
      final Offset center = Offset(sumX / mapped.length, sumY / mapped.length);

      final double outerRadius = 18.0 + (pulseValue * 8.0);
      canvas.drawCircle(
        center,
        outerRadius,
        Paint()
          ..color = anchorColor.withValues(alpha: 0.35 * (1.0 - pulseValue * 0.5))
          ..style = PaintingStyle.fill,
      );
      canvas.drawCircle(
        center,
        11.0,
        Paint()
          ..color = anchorColor
          ..style = PaintingStyle.fill,
      );
      canvas.drawCircle(
        center,
        11.0,
        Paint()
          ..color = Colors.white
          ..strokeWidth = 2.5
          ..style = PaintingStyle.stroke,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CornerAnchorPainter oldDelegate) {
    return oldDelegate.results != results ||
        oldDelegate.pulseValue != pulseValue ||
        oldDelegate.viewportSize != viewportSize;
  }
}
