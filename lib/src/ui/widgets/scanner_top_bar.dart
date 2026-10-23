import 'package:material_ui/material_ui.dart';

import '../../models/barcode_enums.dart';
import '../../models/scanner_state.dart';
import '../../models/scanner_texts.dart';
import '../scanner_builders.dart';
import 'circle_glass_icon_button.dart';

/// Top bar of the scanner view containing the back button, hint badge, and camera switch button.
class ScannerTopBar extends StatelessWidget {
  const ScannerTopBar({
    super.key,
    required this.state,
    required this.texts,
    required this.errorColor,
    required this.topBarBuilder,
    required this.hintTextBuilder,
    required this.onSwitchCamera,
  });

  final ScannerState state;
  final XueHuaScannerTexts texts;
  final Color errorColor;
  final XueHuaTopBarBuilder? topBarBuilder;
  final XueHuaHintTextBuilder? hintTextBuilder;
  final VoidCallback onSwitchCamera;

  @override
  Widget build(BuildContext context) {
    void onBack() {
      Navigator.of(context).maybePop();
    }

    if (topBarBuilder != null) {
      return topBarBuilder!(context, state, onBack, onSwitchCamera);
    }

    final bool isError = state.hasValidationError;
    final String displayPrompt = isError
        ? (state.lastGalleryScanStatus == GalleryScanStatus.noBarcodeFound
              ? texts.noBarcodeInImageText
              : texts.invalidBarcodeText)
        : texts.hintText;

    final Widget hintWidget = hintTextBuilder != null
        ? hintTextBuilder!(context, state)
        : AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: isError
                  ? errorColor.withValues(alpha: 0.24)
                  : Colors.black.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isError
                    ? errorColor.withValues(alpha: 0.85)
                    : Colors.white.withValues(alpha: 0.14),
              ),
            ),
            child: Text(
              displayPrompt,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isError ? errorColor : Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.5,
              ),
            ),
          );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          CircleGlassIconButton(
            key: const ValueKey<String>('xh_scanner_back_button'),
            icon: Icons.arrow_back_ios_new_rounded,
            tooltip: texts.backButtonTooltip,
            onPressed: onBack,
          ),
          Expanded(child: Center(child: hintWidget)),
          CircleGlassIconButton(
            key: const ValueKey<String>('xh_scanner_switch_camera_button'),
            icon: Icons.cameraswitch_rounded,
            tooltip: texts.switchCameraTooltip,
            onPressed: onSwitchCamera,
          ),
        ],
      ),
    );
  }
}
