import 'package:material_ui/material_ui.dart';

/// Circular frosted glassmorphic icon button with tactile press scale feedback
/// used in the scanner top navigation bar.
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
    return IconButton(
      onPressed: onPressed,
      icon: Icon(icon),
      tooltip: tooltip,
      enableFeedback: true,
      style: IconButton.styleFrom(
        backgroundColor: Colors.black.withValues(alpha: 0.75),
        foregroundColor: Colors.white,
        shadowColor: Colors.white24,
      ),
    );
  }
}
