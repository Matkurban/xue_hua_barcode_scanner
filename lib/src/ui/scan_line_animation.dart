import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

/// Unidirectional top-to-bottom optical mesh curtain scan line.
///
/// Renders a three-layer optical effect:
/// 1. **Trailing Gradient Curtain**: Soft upward-fading emerald light curtain.
/// 2. **Optical Mesh Grid**: Perspective grid & micro-dot matrix inside the curtain.
/// 3. **Leading Bright Edge**: Tapered neon laser core with a luminous center highlight.
///
/// Driven directly via `CustomPainter(repaint: animation)` inside a
/// [RepaintBoundary], achieving 60/120 FPS animation with zero widget rebuilds.
class ScanLineAnimation extends StatelessWidget {
  /// Creates a [ScanLineAnimation].
  const ScanLineAnimation({
    super.key,
    required this.animation,
    required this.scanWindow,
    this.lineColor = const Color(0xFF07C160),
    this.lineHeight = 2.6,
    this.glowHeight = 72.0,
    this.horizontalPadding = 12.0,
    this.fullWidth = false,
    this.showGridMesh = true,
  });

  /// Driving animation (`0.0` -> `1.0`).
  final Animation<double> animation;

  /// Bounds of the central scan region.
  final Rect scanWindow;

  /// Primary scan line color (defaults to `#07C160`).
  final Color lineColor;

  /// Core thickness of the leading bright edge.
  final double lineHeight;

  /// Height of the trailing gradient optical mesh curtain above the scan line.
  final double glowHeight;

  /// Horizontal inset from the left and right edges of the scan area.
  final double horizontalPadding;

  /// When `true`, expands the scan line horizontally across the viewport
  /// instead of confining it strictly to [scanWindow.width].
  final bool fullWidth;

  /// Whether to draw the optical grid & dot matrix inside the trailing curtain.
  final bool showGridMesh;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          size: Size.infinite,
          painter: _ScanLinePainter(
            animation: animation,
            scanWindow: scanWindow,
            lineColor: lineColor,
            lineHeight: lineHeight,
            glowHeight: glowHeight,
            horizontalPadding: horizontalPadding,
            fullWidth: fullWidth,
            showGridMesh: showGridMesh,
          ),
        ),
      ),
    );
  }
}

class _ScanLinePainter extends CustomPainter {
  _ScanLinePainter({
    required this.animation,
    required this.scanWindow,
    required this.lineColor,
    required this.lineHeight,
    required this.glowHeight,
    required this.horizontalPadding,
    required this.fullWidth,
    required this.showGridMesh,
  }) : super(repaint: animation);

  final Animation<double> animation;
  final Rect scanWindow;
  final Color lineColor;
  final double lineHeight;
  final double glowHeight;
  final double horizontalPadding;
  final bool fullWidth;
  final bool showGridMesh;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect effectiveBounds = fullWidth
        ? Rect.fromLTWH(
            math.max(16.0, size.width * 0.06),
            math.max(88.0, size.height * 0.16),
            math.max(0.0, size.width - math.max(32.0, size.width * 0.12)),
            math.max(160.0, size.height * 0.56),
          )
        : scanWindow;

    final double lineWidth = math.max(
      0.0,
      effectiveBounds.width - (horizontalPadding * 2),
    );
    if (lineWidth <= 0 || effectiveBounds.height <= 0) {
      return;
    }

    const double verticalMargin = 10.0;
    final double travelRange = math.max(
      0.0,
      effectiveBounds.height - (verticalMargin * 2) - lineHeight,
    );
    final double t = animation.value.clamp(0.0, 1.0);

    // Smooth fade-in at top (0.0..0.12) and fade-out at bottom (0.86..1.0).
    double envelopeAlpha = 1.0;
    if (t < 0.12) {
      envelopeAlpha = (t / 0.12).clamp(0.0, 1.0);
    } else if (t > 0.86) {
      envelopeAlpha = ((1.0 - t) / 0.14).clamp(0.0, 1.0);
    }
    if (envelopeAlpha <= 0.01) {
      return;
    }

    final double currentY =
        effectiveBounds.top + verticalMargin + (travelRange * t);
    final double left = effectiveBounds.left + horizontalPadding;
    final double centerY = currentY + (lineHeight / 2.0);
    final double activeTrailHeight = math.min(
      glowHeight,
      math.max(18.0, currentY - effectiveBounds.top + 12.0),
    );
    final Rect curtainRect = Rect.fromLTWH(
      left,
      centerY - activeTrailHeight,
      lineWidth,
      activeTrailHeight,
    );

    // 1. Trailing gradient curtain above the leading edge.
    final Paint curtainPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          lineColor.withValues(alpha: 0.0),
          lineColor.withValues(alpha: 0.08 * envelopeAlpha),
          lineColor.withValues(alpha: 0.28 * envelopeAlpha),
        ],
        stops: const <double>[0.0, 0.55, 1.0],
      ).createShader(curtainRect);

    final RRect curtainRRect = RRect.fromRectAndCorners(
      curtainRect,
      bottomLeft: const Radius.circular(4),
      bottomRight: const Radius.circular(4),
    );
    canvas.save();
    canvas.clipRRect(curtainRRect);
    canvas.drawRect(curtainRect, curtainPaint);

    // 2. Custom optical mesh grid & glowing micro-dots inside the curtain.
    if (showGridMesh && lineWidth > 40 && activeTrailHeight > 16) {
      const double stepX = 16.0;
      const double stepY = 10.0;
      final Paint meshLinePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.75;
      final Paint dotPaint = Paint()..style = PaintingStyle.fill;

      // Horizontal mesh lines fading upward.
      for (double dy = stepY; dy < activeTrailHeight; dy += stepY) {
        final double y = centerY - dy;
        final double vFactor = (1.0 - (dy / activeTrailHeight)).clamp(0.0, 1.0);
        meshLinePaint.color = lineColor.withValues(
          alpha: 0.18 * vFactor * envelopeAlpha,
        );
        canvas.drawLine(
          Offset(left, y),
          Offset(left + lineWidth, y),
          meshLinePaint,
        );
      }

      // Vertical mesh lines & intersection micro-dots fading toward edges.
      final double halfW = lineWidth / 2.0;
      for (double dx = stepX; dx < lineWidth; dx += stepX) {
        final double x = left + dx;
        final double hDist = ((dx - halfW).abs() / halfW).clamp(0.0, 1.0);
        final double hFactor = 1.0 - (hDist * hDist * 0.75);
        meshLinePaint.shader =
            LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[
                lineColor.withValues(alpha: 0.0),
                lineColor.withValues(alpha: 0.22 * hFactor * envelopeAlpha),
              ],
            ).createShader(
              Rect.fromLTWH(x, curtainRect.top, 1.0, activeTrailHeight),
            );
        canvas.drawLine(
          Offset(x, curtainRect.top),
          Offset(x, centerY),
          meshLinePaint,
        );

        for (double dy = stepY; dy < activeTrailHeight; dy += stepY) {
          final double y = centerY - dy;
          final double vFactor = (1.0 - (dy / activeTrailHeight)).clamp(
            0.0,
            1.0,
          );
          final double dotAlpha = (0.42 * vFactor * hFactor * envelopeAlpha)
              .clamp(0.0, 1.0);
          if (dotAlpha > 0.04) {
            dotPaint.color = Color.lerp(
              lineColor,
              Colors.white,
              0.35,
            )!.withValues(alpha: dotAlpha);
            canvas.drawCircle(Offset(x, y), 1.15, dotPaint);
          }
        }
      }
    }
    canvas.restore();

    // 3. Soft ambient elliptical halo around the leading edge.
    final Rect haloRect = Rect.fromLTWH(left, centerY - 8.0, lineWidth, 16.0);
    final Paint haloPaint = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 0.65,
        colors: <Color>[
          lineColor.withValues(alpha: 0.42 * envelopeAlpha),
          lineColor.withValues(alpha: 0.14 * envelopeAlpha),
          lineColor.withValues(alpha: 0.0),
        ],
        stops: const <double>[0.0, 0.55, 1.0],
      ).createShader(haloRect);
    canvas.drawOval(haloRect, haloPaint);

    // 4. Outer neon bloom along the horizontal scan line.
    final Rect bloomRect = Rect.fromLTWH(
      left + 4.0,
      centerY - 3.0,
      math.max(0.0, lineWidth - 8.0),
      6.0,
    );
    final Paint bloomPaint = Paint()
      ..shader = LinearGradient(
        colors: <Color>[
          lineColor.withValues(alpha: 0.0),
          lineColor.withValues(alpha: 0.52 * envelopeAlpha),
          lineColor.withValues(alpha: 0.78 * envelopeAlpha),
          lineColor.withValues(alpha: 0.52 * envelopeAlpha),
          lineColor.withValues(alpha: 0.0),
        ],
        stops: const <double>[0.0, 0.18, 0.5, 0.82, 1.0],
      ).createShader(bloomRect)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.5);
    canvas.drawRRect(
      RRect.fromRectAndRadius(bloomRect, const Radius.circular(4.0)),
      bloomPaint,
    );

    // 5. Crisp tapered laser core with bright white-emerald center highlight.
    final Rect lineRect = Rect.fromLTWH(left, currentY, lineWidth, lineHeight);
    final Color highlightColor = Color.lerp(
      lineColor,
      Colors.white,
      0.62,
    )!.withValues(alpha: envelopeAlpha);
    final Paint corePaint = Paint()
      ..shader = LinearGradient(
        colors: <Color>[
          lineColor.withValues(alpha: 0.0),
          lineColor.withValues(alpha: 0.90 * envelopeAlpha),
          highlightColor,
          lineColor.withValues(alpha: 0.90 * envelopeAlpha),
          lineColor.withValues(alpha: 0.0),
        ],
        stops: const <double>[0.0, 0.15, 0.5, 0.85, 1.0],
      ).createShader(lineRect);
    canvas.drawRRect(
      RRect.fromRectAndRadius(lineRect, Radius.circular(lineHeight)),
      corePaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ScanLinePainter oldDelegate) {
    return oldDelegate.scanWindow != scanWindow ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.lineHeight != lineHeight ||
        oldDelegate.glowHeight != glowHeight ||
        oldDelegate.horizontalPadding != horizontalPadding ||
        oldDelegate.fullWidth != fullWidth ||
        oldDelegate.showGridMesh != showGridMesh;
  }
}
