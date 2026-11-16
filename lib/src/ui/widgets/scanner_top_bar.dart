import 'package:material_ui/material_ui.dart';

import '../../models/camera_input_source.dart';
import '../../models/scanner_state.dart';
import '../../models/scanner_texts.dart';
import '../scanner_builders.dart';
import 'circle_glass_icon_button.dart';
import 'scanner_camera_source_button.dart';

/// WeChat Scan-style top bar containing the circular close (`×`) button (or
/// "取消" button when paused in multi-barcode selection mode) and multi-camera
/// source switch button.
class ScannerTopBar extends StatelessWidget {
  const ScannerTopBar({
    super.key,
    required this.state,
    required this.texts,
    required this.errorColor,
    required this.topBarBuilder,
    required this.onSwitchCamera,
    required this.onSelectCamera,
    this.onCancelMultiSelect,
  });

  final ScannerState state;
  final XueHuaScannerTexts texts;
  final Color errorColor;
  final XueHuaTopBarBuilder? topBarBuilder;
  final VoidCallback onSwitchCamera;
  final ValueChanged<CameraInputSource> onSelectCamera;
  final VoidCallback? onCancelMultiSelect;

  @override
  Widget build(BuildContext context) {
    void onBack() {
      Navigator.of(context).maybePop();
    }

    if (topBarBuilder != null) {
      return topBarBuilder!(context, state, onBack, onSwitchCamera);
    }

    final bool isMultiSelect = state.isSelectingMultiBarcode;

    return RepaintBoundary(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            if (isMultiSelect)
              _WeChatCancelMultiSelectButton(
                key: const ValueKey<String>(
                  'xh_scanner_cancel_multi_select_button',
                ),
                label: texts.cancelMultiSelectLabel,
                onPressed: onCancelMultiSelect ?? onBack,
              )
            else
              CircleGlassIconButton(
                key: const ValueKey<String>('xh_scanner_back_button'),
                icon: Icons.close_rounded,
                tooltip: texts.backButtonTooltip,
                onPressed: onBack,
              ),
            if (!isMultiSelect && state.cameras.length > 1)
              XueHuaCameraSourceButton(
                sources: state.cameras,
                activeSourceId: state.activeCameraId,
                tooltip: texts.selectInputSourceTooltip,
                onSelected: onSelectCamera,
              )
            else
              const SizedBox(width: 44, height: 44),
          ],
        ),
      ),
    );
  }
}

class _WeChatCancelMultiSelectButton extends StatefulWidget {
  const _WeChatCancelMultiSelectButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  State<_WeChatCancelMultiSelectButton> createState() =>
      _WeChatCancelMultiSelectButtonState();
}

class _WeChatCancelMultiSelectButtonState
    extends State<_WeChatCancelMultiSelectButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onPressed,
      behavior: HitTestBehavior.opaque,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 100),
        opacity: _isPressed ? 0.65 : 1.0,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0x66000000),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
          ),
          child: Text(
            widget.label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.3,
            ),
          ),
        ),
      ),
    );
  }
}
