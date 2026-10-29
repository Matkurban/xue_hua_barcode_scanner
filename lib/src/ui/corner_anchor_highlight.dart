import 'package:flutter/foundation.dart' show listEquals;
import 'package:material_ui/material_ui.dart';

import '../models/barcode_result.dart';

/// Draws pulsing AR target reticles and corner polygons over detected barcodes.
///
/// Uses `CustomPainter(repaint: _pulseController)` inside a [RepaintBoundary]
/// so pulsing animations never rebuild the widget tree.
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

  /// Detected barcode results with `cornerPoints`.
  final List<BarcodeResult> results;

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
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.results.isEmpty) {
      return const SizedBox.shrink();
    }
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          size: widget.viewportSize,
          painter: _CornerAnchorPainter(
            pulseAnimation: _pulseController,
            results: widget.results,
            viewportSize: widget.viewportSize,
            sensorOrientation: widget.sensorOrientation,
            isFrontCamera: widget.isFrontCamera,
            anchorColor: widget.anchorColor,
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

class _CornerAnchorPainter extends CustomPainter {
  _CornerAnchorPainter({
    required this.pulseAnimation,
    required this.results,
    required this.viewportSize,
    required this.sensorOrientation,
    required this.isFrontCamera,
    required this.anchorColor,
  }) : super(repaint: pulseAnimation);

  final Animation<double> pulseAnimation;
  final List<BarcodeResult> results;
  final Size viewportSize;
  final int sensorOrientation;
  final bool isFrontCamera;
  final Color anchorColor;

  @override
  void paint(Canvas canvas, Size size) {
    final double pulseValue = pulseAnimation.value;

    final Paint polyFillPaint = Paint()
      ..color = anchorColor.withValues(alpha: 0.16)
      ..style = PaintingStyle.fill;
    final Paint polyStrokePaint = Paint()
      ..color = anchorColor.withValues(alpha: 0.90)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    final Paint sonarPaint = Paint()
      ..color = anchorColor.withValues(alpha: 0.36 * (1.0 - pulseValue * 0.55))
      ..style = PaintingStyle.fill;
    final Paint sonarRingPaint = Paint()
      ..color = anchorColor.withValues(alpha: 0.55 * (1.0 - pulseValue * 0.45))
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    final Paint coreFillPaint = Paint()
      ..color = anchorColor
      ..style = PaintingStyle.fill;
    final Paint whiteRingPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;
    final Paint centerDotPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    for (final BarcodeResult result in results) {
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

        canvas.drawPath(poly, polyFillPaint);
        canvas.drawPath(poly, polyStrokePaint);
      }

      double sumX = 0;
      double sumY = 0;
      for (final Offset pt in mapped) {
        sumX += pt.dx;
        sumY += pt.dy;
      }
      final Offset center = Offset(sumX / mapped.length, sumY / mapped.length);

      final double outerRadius = 17.0 + (pulseValue * 9.0);
      canvas.drawCircle(center, outerRadius, sonarPaint);
      canvas.drawCircle(center, outerRadius, sonarRingPaint);
      canvas.drawCircle(center, 11.5, coreFillPaint);
      canvas.drawCircle(center, 11.5, whiteRingPaint);
      canvas.drawCircle(center, 3.2, centerDotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _CornerAnchorPainter oldDelegate) {
    return !listEquals(oldDelegate.results, results) ||
        oldDelegate.viewportSize != viewportSize ||
        oldDelegate.sensorOrientation != sensorOrientation ||
        oldDelegate.isFrontCamera != isFrontCamera ||
        oldDelegate.anchorColor != anchorColor;
  }
}
