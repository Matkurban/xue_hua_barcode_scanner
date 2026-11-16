import 'package:material_ui/material_ui.dart';

import '../../models/camera_input_source.dart';
import '../../models/scanner_state.dart';
import '../../models/scanner_texts.dart';
import '../scanner_builders.dart';
import 'circle_glass_icon_button.dart';
import 'scanner_camera_source_button.dart';

/// Top bar of the scanner view containing the circular close (`×`) button
/// (or "取消" button when paused in multi-barcode selection mode) and
/// multi-camera source switch button.
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
  final ScannerTexts texts;
  final Color errorColor;
  final TopBarBuilder? topBarBuilder;
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
              TextButton(
                key: const ValueKey<String>(
                  'xh_scanner_cancel_multi_select_button',
                ),
                onPressed: onCancelMultiSelect ?? onBack,
                style: TextButton.styleFrom(
                  backgroundColor: Colors.black.withValues(alpha: 0.48),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: const StadiumBorder(),
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.16)),
                ),
                child: Text(
                  texts.cancelMultiSelectLabel,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.3,
                  ),
                ),
              )
            else
              CircleGlassIconButton(
                key: const ValueKey<String>('xh_scanner_back_button'),
                icon: Icons.close_rounded,
                tooltip: texts.backButtonTooltip,
                onPressed: onBack,
              ),
            if (!isMultiSelect && state.cameras.length > 1)
              CameraSourceButton(
                sources: state.cameras,
                activeSourceId: state.activeCameraId,
                tooltip: texts.selectInputSourceTooltip,
                onSelected: onSelectCamera,
              )
            else
              const SizedBox(width: 42, height: 42),
          ],
        ),
      ),
    );
  }
}
