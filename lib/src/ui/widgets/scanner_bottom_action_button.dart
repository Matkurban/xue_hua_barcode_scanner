import 'package:material_ui/material_ui.dart';

/// Tactile glassmorphic circular action button with label used in the scanner
/// bottom bar (Torch & Gallery).
class ScannerBottomActionButton extends StatefulWidget {
  const ScannerBottomActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.isActive,
    required this.isEnabled,
    required this.activeColor,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isActive;
  final bool isEnabled;
  final Color activeColor;
  final VoidCallback onTap;

  @override
  State<ScannerBottomActionButton> createState() =>
      _ScannerBottomActionButtonState();
}

class _ScannerBottomActionButtonState extends State<ScannerBottomActionButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final bool active = widget.isActive;
    final bool enabled = widget.isEnabled;
    final Color accent = widget.activeColor;

    final Color borderColor = active
        ? accent
        : Colors.white.withValues(alpha: enabled ? 0.24 : 0.12);
    final Color iconColor = active
        ? accent
        : Colors.white.withValues(alpha: enabled ? 0.96 : 0.45);

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: _isPressed ? 0.92 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: active
                      ? <Color>[
                          accent.withValues(alpha: 0.34),
                          accent.withValues(alpha: 0.16),
                        ]
                      : <Color>[
                          const Color(0xA61E293B),
                          const Color(0xCC090D16),
                        ],
                ),
                border: Border.all(
                  color: borderColor,
                  width: active ? 1.8 : 1.2,
                ),
                boxShadow: <BoxShadow>[
                  if (active)
                    BoxShadow(
                      color: accent.withValues(alpha: 0.42),
                      blurRadius: 16,
                      spreadRadius: 1.5,
                    )
                  else
                    const BoxShadow(
                      color: Color(0x59000000),
                      blurRadius: 14,
                      offset: Offset(0, 5),
                    ),
                ],
              ),
              child: Icon(widget.icon, color: iconColor, size: 26),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: active
                    ? accent.withValues(alpha: 0.16)
                    : Colors.black.withValues(alpha: 0.38),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                widget.label,
                style: TextStyle(
                  color: active ? accent : iconColor,
                  fontSize: 12.5,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
