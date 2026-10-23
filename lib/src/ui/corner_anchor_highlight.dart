import 'package:material_ui/material_ui.dart';

import '../models/barcode_result.dart';

/// Draws pulsing anchor points and corner polygons over detected barcodes.
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
      duration: const Duration(milliseconds: 650),
    )..repeat(reverse: true);
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

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
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

  final List<BarcodeResult> results;
  final Size viewportSize;
  final int sensorOrientation;
  final bool isFrontCamera;
  final Color anchorColor;
  final double pulseValue;

  @override
  void paint(Canvas canvas, Size size) {
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
          ..color = anchorColor.withValues(
            alpha: 0.35 * (1.0 - pulseValue * 0.5),
          )
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
        oldDelegate.viewportSize != viewportSize ||
        oldDelegate.anchorColor != anchorColor;
  }
}
