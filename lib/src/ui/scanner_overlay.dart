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

    final Path maskPath = Path.combine(
      PathOperation.difference,
      fullScreenPath,
      cutoutPath,
    );
    final Paint maskPaint = Paint()
      ..color = maskColor
      ..style = PaintingStyle.fill;
    canvas.drawPath(maskPath, maskPaint);

    if (borderStrokeWidth > 0) {
      final Paint borderPaint = Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = borderStrokeWidth;
      canvas.drawRRect(cutoutRRect, borderPaint);
    }

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
      ..moveTo(left, top + l)
      ..lineTo(left, top + r)
      ..arcToPoint(
        Offset(left + r, top),
        radius: Radius.circular(r),
      )
      ..lineTo(left + l, top)
      ..moveTo(right - l, top)
      ..lineTo(right - r, top)
      ..arcToPoint(
        Offset(right, top + r),
        radius: Radius.circular(r),
      )
      ..lineTo(right, top + l)
      ..moveTo(right, bottom - l)
      ..lineTo(right, bottom - r)
      ..arcToPoint(
        Offset(right - r, bottom),
        radius: Radius.circular(r),
      )
      ..lineTo(right - l, bottom)
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
        oldDelegate.cornerStrokeWidth != cornerStrokeWidth ||
        oldDelegate.borderStrokeWidth != borderStrokeWidth;
  }
}
