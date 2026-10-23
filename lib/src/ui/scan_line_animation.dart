import 'dart:math' as math;
import 'package:material_ui/material_ui.dart';

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
          const double verticalMargin = 12.0;
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
