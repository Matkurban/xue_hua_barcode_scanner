import 'package:material_ui/material_ui.dart';

import '../../models/barcode_enums.dart';
import '../../models/camera_input_source.dart';
import '../../models/scanner_state.dart';
import '../../models/scanner_texts.dart';
import '../scanner_builders.dart';
import 'circle_glass_icon_button.dart';
import 'scanner_camera_source_button.dart';

/// Top bar of the scanner view containing the back button, HUD status pill,
/// and multi-camera source switch button.
class ScannerTopBar extends StatelessWidget {
  const ScannerTopBar({
    super.key,
    required this.state,
    required this.texts,
    required this.errorColor,
    required this.topBarBuilder,
    required this.hintTextBuilder,
    required this.onSwitchCamera,
    required this.onSelectCamera,
  });

  final ScannerState state;
  final XueHuaScannerTexts texts;
  final Color errorColor;
  final XueHuaTopBarBuilder? topBarBuilder;
  final XueHuaHintTextBuilder? hintTextBuilder;
  final VoidCallback onSwitchCamera;
  final ValueChanged<CameraInputSource> onSelectCamera;

  @override
  Widget build(BuildContext context) {
    void onBack() {
      Navigator.of(context).maybePop();
    }

    if (topBarBuilder != null) {
      return topBarBuilder!(context, state, onBack, onSwitchCamera);
    }

    final bool isError = state.hasValidationError;
    final bool isPermDenied = state.isPermissionDenied;
    final String displayPrompt = isError
        ? (state.lastGalleryScanStatus == GalleryScanStatus.noBarcodeFound
              ? texts.noBarcodeInImageText
              : texts.invalidBarcodeText)
        : texts.hintText;

    final Color accentColor = isError
        ? errorColor
        : (isPermDenied ? const Color(0xFFF59E0B) : const Color(0xFF00E676));

    final Widget hintWidget = hintTextBuilder != null
        ? hintTextBuilder!(context, state)
        : AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isError
                    ? <Color>[
                        errorColor.withValues(alpha: 0.28),
                        errorColor.withValues(alpha: 0.16),
                      ]
                    : <Color>[const Color(0x991E293B), const Color(0xB8090D16)],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isError
                    ? errorColor.withValues(alpha: 0.85)
                    : (isPermDenied
                          ? const Color(0x66F59E0B)
                          : Colors.white.withValues(alpha: 0.18)),
              ),
              boxShadow: const <BoxShadow>[
                BoxShadow(
                  color: Color(0x4D000000),
                  blurRadius: 14,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                _StatusIndicatorBadge(
                  isError: isError,
                  isPermissionDenied: isPermDenied,
                  isPaused: state.isPaused,
                  accentColor: accentColor,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    displayPrompt,
                    key: const ValueKey<String>('xh_scanner_hint'),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isError ? errorColor : Colors.white,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ],
            ),
          );

    return RepaintBoundary(
      child: Padding(
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
            const SizedBox(width: 12),
            Expanded(child: Center(child: hintWidget)),
            const SizedBox(width: 12),
            if (state.cameras.length > 1)
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

class _StatusIndicatorBadge extends StatelessWidget {
  const _StatusIndicatorBadge({
    required this.isError,
    required this.isPermissionDenied,
    required this.isPaused,
    required this.accentColor,
  });

  final bool isError;
  final bool isPermissionDenied;
  final bool isPaused;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    if (isError) {
      return Icon(Icons.error_outline_rounded, color: accentColor, size: 16);
    }
    if (isPermissionDenied) {
      return Icon(Icons.lock_person_rounded, color: accentColor, size: 15);
    }
    if (isPaused) {
      return const Icon(
        Icons.pause_circle_outline_rounded,
        color: Colors.white70,
        size: 15,
      );
    }
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: accentColor,
        shape: BoxShape.circle,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: accentColor.withValues(alpha: 0.70),
            blurRadius: 6,
            spreadRadius: 1,
          ),
        ],
      ),
    );
  }
}
