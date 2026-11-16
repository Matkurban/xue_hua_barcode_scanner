import 'package:material_ui/material_ui.dart';

/// Lightweight circular action button with caption label used in the scanner
/// bottom bar (Torch & Gallery).
class ScannerBottomActionButton extends StatelessWidget {
  /// Creates a [ScannerBottomActionButton].
  const ScannerBottomActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.isActive,
    required this.isEnabled,
    required this.activeColor,
    required this.onTap,
  });

  /// Icon displayed inside the circular button.
  final IconData icon;

  /// Text caption displayed below the circular button.
  final String label;

  /// Whether the action is currently toggled on (e.g. torch illuminated).
  final bool isActive;

  /// Whether the underlying hardware feature is available.
  final bool isEnabled;

  /// Accent color used when [isActive] is `true`.
  final Color activeColor;

  /// Callback invoked when the button or its caption is tapped.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color foregroundColor = isActive
        ? activeColor
        : Colors.white.withValues(alpha: isEnabled ? 0.92 : 0.45);
    final Color backgroundColor = isActive
        ? activeColor.withValues(alpha: 0.22)
        : Colors.black.withValues(alpha: 0.48);
    final Color borderColor = isActive
        ? activeColor.withValues(alpha: 0.65)
        : Colors.white.withValues(alpha: isEnabled ? 0.14 : 0.08);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          IconButton(
            onPressed: onTap,
            icon: Icon(icon, size: 24),
            enableFeedback: true,
            style: IconButton.styleFrom(
              backgroundColor: backgroundColor,
              foregroundColor: foregroundColor,
              highlightColor: Colors.white.withValues(alpha: 0.14),
              fixedSize: const Size.square(52),
              minimumSize: const Size.square(52),
              padding: EdgeInsets.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: const CircleBorder(),
              side: BorderSide(color: borderColor),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              color: foregroundColor,
              fontSize: 12,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}
