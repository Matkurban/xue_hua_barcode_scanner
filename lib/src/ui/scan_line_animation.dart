import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

/// Smooth vertical back-and-forth laser scan line with multi-layered optical
/// glow rendered inside [scanWindow].
///
/// Driven directly via `CustomPainter(repaint: animation)` inside a
/// [RepaintBoundary], achieving 60/120 FPS animation with zero widget rebuilds
/// and zero layout passes per frame.
class XueHuaScanLineAnimation extends StatelessWidget {
  /// Creates a [XueHuaScanLineAnimation].
  const XueHuaScanLineAnimation({
    super.key,
    required this.animation,
    required this.scanWindow,
    this.lineColor = const Color(0xFF00E676),
    this.lineHeight = 2.8,
    this.glowHeight = 42.0,
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
      child: RepaintBoundary(
        child: CustomPaint(
          size: Size.infinite,
          painter: _XueHuaScanLinePainter(
            animation: animation,
            scanWindow: scanWindow,
            lineColor: lineColor,
            lineHeight: lineHeight,
            glowHeight: glowHeight,
            horizontalPadding: horizontalPadding,
          ),
        ),
      ),
    );
  }
}

class _XueHuaScanLinePainter extends CustomPainter {
  _XueHuaScanLinePainter({
    required this.animation,
    required this.scanWindow,
    required this.lineColor,
    required this.lineHeight,
    required this.glowHeight,
    required this.horizontalPadding,
  }) : super(repaint: animation);

  final Animation<double> animation;
  final Rect scanWindow;
  final Color lineColor;
  final double lineHeight;
  final double glowHeight;
  final double horizontalPadding;

  @override
  void paint(Canvas canvas, Size size) {
    final double lineWidth = math.max(
      0.0,
      scanWindow.width - (horizontalPadding * 2),
    );
    if (lineWidth <= 0 || scanWindow.height <= 0) {
      return;
    }

    const double verticalMargin = 14.0;
    final double travelRange = math.max(
      0.0,
      scanWindow.height - (verticalMargin * 2) - lineHeight,
    );
    final double t = animation.value.clamp(0.0, 1.0);
    final double currentY = scanWindow.top + verticalMargin + (travelRange * t);
    final double left = scanWindow.left + horizontalPadding;
    final double centerY = currentY + (lineHeight / 2.0);

    // 1. Soft vertical & horizontal curtain glow around the laser beam.
    final Rect glowRect = Rect.fromLTWH(
      left,
      centerY - (glowHeight / 2.0),
      lineWidth,
      glowHeight,
    );
    final Paint glowPaint = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 0.75,
        colors: <Color>[
          lineColor.withValues(alpha: 0.30),
          lineColor.withValues(alpha: 0.12),
          lineColor.withValues(alpha: 0.0),
        ],
        stops: const <double>[0.0, 0.55, 1.0],
      ).createShader(glowRect);
    canvas.drawOval(glowRect, glowPaint);

    // 2. Soft outer neon bloom along the horizontal scan line.
    final Rect bloomRect = Rect.fromLTWH(
      left + 6.0,
      centerY - 3.5,
      math.max(0.0, lineWidth - 12.0),
      7.0,
    );
    final Paint bloomPaint = Paint()
      ..shader = LinearGradient(
        colors: <Color>[
          lineColor.withValues(alpha: 0.0),
          lineColor.withValues(alpha: 0.48),
          lineColor.withValues(alpha: 0.68),
          lineColor.withValues(alpha: 0.48),
          lineColor.withValues(alpha: 0.0),
        ],
        stops: const <double>[0.0, 0.2, 0.5, 0.8, 1.0],
      ).createShader(bloomRect)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0);
    canvas.drawRRect(
      RRect.fromRectAndRadius(bloomRect, const Radius.circular(4.0)),
      bloomPaint,
    );

    // 3. Crisp tapered laser core with bright center highlight.
    final Rect lineRect = Rect.fromLTWH(left, currentY, lineWidth, lineHeight);
    final Color highlightColor = Color.lerp(lineColor, Colors.white, 0.65)!;
    final Paint corePaint = Paint()
      ..shader = LinearGradient(
        colors: <Color>[
          lineColor.withValues(alpha: 0.0),
          lineColor.withValues(alpha: 0.88),
          highlightColor,
          lineColor.withValues(alpha: 0.88),
          lineColor.withValues(alpha: 0.0),
        ],
        stops: const <double>[0.0, 0.18, 0.5, 0.82, 1.0],
      ).createShader(lineRect);
    canvas.drawRRect(
      RRect.fromRectAndRadius(lineRect, Radius.circular(lineHeight)),
      corePaint,
    );
  }

  @override
  bool shouldRepaint(covariant _XueHuaScanLinePainter oldDelegate) {
    return oldDelegate.scanWindow != scanWindow ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.lineHeight != lineHeight ||
        oldDelegate.glowHeight != glowHeight ||
        oldDelegate.horizontalPadding != horizontalPadding;
  }
}
