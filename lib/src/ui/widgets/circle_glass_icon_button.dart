import 'package:material_ui/material_ui.dart';

/// Circular frosted glass icon button used in the scanner top navigation bar.
class CircleGlassIconButton extends StatelessWidget {
  const CircleGlassIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.45),
      shape: CircleBorder(
        side: BorderSide(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: IconButton(
        tooltip: tooltip,
        icon: Icon(icon, color: Colors.white, size: 20),
        onPressed: onPressed,
      ),
    );
  }
}
