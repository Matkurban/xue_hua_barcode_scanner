import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

/// Calculates the centered square scan window [Rect] inside [viewportSize].
Rect calculateScanWindowRect(
  Size viewportSize, {
  double? customCutoutSize,
  double verticalOffset = -20.0,
}) {
  final double shortestSide = math.min(viewportSize.width, viewportSize.height);
  final double defaultSize = (shortestSide * 0.68).clamp(200.0, 320.0);
  final double boxSize = (customCutoutSize ?? defaultSize).clamp(
    140.0,
    shortestSide * 0.9,
  );
  final double left = (viewportSize.width - boxSize) / 2.0;
  final double top = ((viewportSize.height - boxSize) / 2.0) + verticalOffset;
  return Rect.fromLTWH(left, top, boxSize, boxSize);
}

/// Full-screen semi-transparent dark mask with a rounded square cutout,
/// subtle optical viewfinder reticle, and four glowing corner brackets (`CustomPainter`).
///
/// Uses [PathFillType.evenOdd] inside a [RepaintBoundary] to avoid expensive
/// `Path.combine` boolean geometry operations on the UI thread.
class XueHuaScannerOverlay extends StatelessWidget {
  /// Creates a [XueHuaScannerOverlay].
  const XueHuaScannerOverlay({
    super.key,
    required this.scanWindow,
    this.maskColor = const Color(0x99000000),
    this.borderColor = const Color(0x38FFFFFF),
    this.cornerColor = const Color(0xFF00E676),
    this.borderRadius = 20.0,
    this.cornerLength = 28.0,
    this.cornerStrokeWidth = 4.0,
    this.borderStrokeWidth = 1.2,
    this.showReticleGrid = true,
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

  /// Whether to draw subtle optical reticle ticks inside [scanWindow].
  final bool showReticleGrid;

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
            showReticleGrid: showReticleGrid,
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
    required this.showReticleGrid,
  });

  final Rect scanWindow;
  final Color maskColor;
  final Color borderColor;
  final Color cornerColor;
  final double borderRadius;
  final double cornerLength;
  final double cornerStrokeWidth;
  final double borderStrokeWidth;
  final bool showReticleGrid;

  @override
  void paint(Canvas canvas, Size size) {
    final RRect cutoutRRect = RRect.fromRectAndRadius(
      scanWindow,
      Radius.circular(borderRadius),
    );

    // Fast hardware-accelerated Even-Odd path fill (avoids expensive Path.combine).
    final Path maskPath = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRRect(cutoutRRect);

    final Paint maskPaint = Paint()
      ..color = maskColor
      ..style = PaintingStyle.fill;
    canvas.drawPath(maskPath, maskPaint);

    // Subtle outer ambient rim around the scan window for visual depth.
    final RRect outerGlowRRect = RRect.fromRectAndRadius(
      scanWindow.inflate(2.0),
      Radius.circular(borderRadius + 2.0),
    );
    canvas.drawRRect(
      outerGlowRRect,
      Paint()
        ..color = cornerColor.withValues(alpha: 0.12)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0,
    );

    // Subtle optical viewfinder reticle ticks & center crosshair inside cutout.
    if (showReticleGrid && scanWindow.width > 120) {
      final Paint reticlePaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.08)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;

      final Offset center = scanWindow.center;
      const double crossArm = 10.0;
      const double crossGap = 4.0;
      canvas.drawLine(
        Offset(center.dx - crossArm, center.dy),
        Offset(center.dx - crossGap, center.dy),
        reticlePaint,
      );
      canvas.drawLine(
        Offset(center.dx + crossGap, center.dy),
        Offset(center.dx + crossArm, center.dy),
        reticlePaint,
      );
      canvas.drawLine(
        Offset(center.dx, center.dy - crossArm),
        Offset(center.dx, center.dy - crossGap),
        reticlePaint,
      );
      canvas.drawLine(
        Offset(center.dx, center.dy + crossGap),
        Offset(center.dx, center.dy + crossArm),
        reticlePaint,
      );

      // Midpoint edge ticks.
      const double tickLen = 6.0;
      canvas.drawLine(
        Offset(center.dx, scanWindow.top + 1),
        Offset(center.dx, scanWindow.top + 1 + tickLen),
        reticlePaint,
      );
      canvas.drawLine(
        Offset(center.dx, scanWindow.bottom - 1),
        Offset(center.dx, scanWindow.bottom - 1 - tickLen),
        reticlePaint,
      );
      canvas.drawLine(
        Offset(scanWindow.left + 1, center.dy),
        Offset(scanWindow.left + 1 + tickLen, center.dy),
        reticlePaint,
      );
      canvas.drawLine(
        Offset(scanWindow.right - 1, center.dy),
        Offset(scanWindow.right - 1 - tickLen, center.dy),
        reticlePaint,
      );
    }

    if (borderStrokeWidth > 0) {
      final Paint borderPaint = Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = borderStrokeWidth;
      canvas.drawRRect(cutoutRRect, borderPaint);
    }

    final double r = borderRadius.clamp(0.0, cornerLength);
    final double l = cornerLength;
    final double left = scanWindow.left;
    final double top = scanWindow.top;
    final double right = scanWindow.right;
    final double bottom = scanWindow.bottom;

    final Path cornersPath = Path()
      ..moveTo(left, top + l)
      ..lineTo(left, top + r)
      ..arcToPoint(Offset(left + r, top), radius: Radius.circular(r))
      ..lineTo(left + l, top)
      ..moveTo(right - l, top)
      ..lineTo(right - r, top)
      ..arcToPoint(Offset(right, top + r), radius: Radius.circular(r))
      ..lineTo(right, top + l)
      ..moveTo(right, bottom - l)
      ..lineTo(right, bottom - r)
      ..arcToPoint(Offset(right - r, bottom), radius: Radius.circular(r))
      ..lineTo(right - l, bottom)
      ..moveTo(left + l, bottom)
      ..lineTo(left + r, bottom)
      ..arcToPoint(Offset(left, bottom - r), radius: Radius.circular(r))
      ..lineTo(left, bottom - l);

    // Soft outer optical bloom behind the corner brackets.
    final Paint cornerGlowPaint = Paint()
      ..color = cornerColor.withValues(alpha: 0.30)
      ..style = PaintingStyle.stroke
      ..strokeWidth = cornerStrokeWidth + 4.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5.0);
    canvas.drawPath(cornersPath, cornerGlowPaint);

    // Crisp foreground corner brackets.
    final Paint cornerPaint = Paint()
      ..color = cornerColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = cornerStrokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
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
        oldDelegate.cornerStrokeWidth != cornerStrokeWidth ||
        oldDelegate.borderStrokeWidth != borderStrokeWidth ||
        oldDelegate.showReticleGrid != showReticleGrid;
  }
}
