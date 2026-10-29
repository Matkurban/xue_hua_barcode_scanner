import 'package:material_ui/material_ui.dart';

/// Circular frosted glassmorphic icon button with tactile press scale feedback
/// used in the scanner top navigation bar.
class CircleGlassIconButton extends StatefulWidget {
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
  State<CircleGlassIconButton> createState() => _CircleGlassIconButtonState();
}

class _CircleGlassIconButtonState extends State<CircleGlassIconButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Tooltip(
        message: widget.tooltip,
        child: GestureDetector(
          onTapDown: (_) => setState(() => _isPressed = true),
          onTapUp: (_) => setState(() => _isPressed = false),
          onTapCancel: () => setState(() => _isPressed = false),
          onTap: widget.onPressed,
          behavior: HitTestBehavior.opaque,
          child: AnimatedScale(
            scale: _isPressed ? 0.91 : 1.0,
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOutCubic,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[
                    _isPressed
                        ? const Color(0xCC1E293B)
                        : const Color(0x991E293B),
                    _isPressed
                        ? const Color(0xE60F172A)
                        : const Color(0xB8090D16),
                  ],
                ),
                border: Border.all(
                  color: Colors.white.withValues(
                    alpha: _isPressed ? 0.34 : 0.20,
                  ),
                ),
                boxShadow: const <BoxShadow>[
                  BoxShadow(
                    color: Color(0x52000000),
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: Icon(widget.icon, color: Colors.white, size: 20),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
