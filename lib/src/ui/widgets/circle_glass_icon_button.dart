import 'package:material_ui/material_ui.dart';

/// Lightweight circular translucent icon button used in the scanner top bar.
class CircleGlassIconButton extends StatelessWidget {
  /// Creates a [CircleGlassIconButton].
  const CircleGlassIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.size = 42.0,
    this.iconSize = 20.0,
  });

  /// Icon displayed inside the circular button.
  final IconData icon;

  /// Accessibility and hover tooltip message.
  final String tooltip;

  /// Callback invoked when the button is tapped.
  final VoidCallback onPressed;

  /// Diameter of the circular button in logical pixels.
  final double size;

  /// Size of [icon] in logical pixels.
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      icon: Icon(icon, size: iconSize),
      tooltip: tooltip,
      enableFeedback: true,
      style: IconButton.styleFrom(
        backgroundColor: Colors.black.withValues(alpha: 0.48),
        foregroundColor: Colors.white,
        highlightColor: Colors.white.withValues(alpha: 0.14),
        fixedSize: Size.square(size),
        minimumSize: Size.square(size),
        padding: EdgeInsets.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: const CircleBorder(),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.14)),
      ),
    );
  }
}
