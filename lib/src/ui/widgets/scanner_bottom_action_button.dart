import 'package:material_ui/material_ui.dart';

/// Circular action button with label used in the scanner bottom bar (Torch & Gallery).
class ScannerBottomActionButton extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final Color bgColor = isActive
        ? activeColor.withValues(alpha: 0.25)
        : Colors.black.withValues(alpha: 0.50);
    final Color borderColor = isActive
        ? activeColor
        : Colors.white.withValues(alpha: isEnabled ? 0.24 : 0.10);
    final Color iconColor = isActive
        ? activeColor
        : Colors.white.withValues(alpha: isEnabled ? 0.95 : 0.40);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: bgColor,
              shape: BoxShape.circle,
              border: Border.all(color: borderColor, width: 1.5),
              boxShadow: isActive
                  ? <BoxShadow>[
                      BoxShadow(
                        color: activeColor.withValues(alpha: 0.45),
                        blurRadius: 14,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            child: Icon(icon, color: iconColor, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: isActive ? activeColor : iconColor,
              fontSize: 13,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}
