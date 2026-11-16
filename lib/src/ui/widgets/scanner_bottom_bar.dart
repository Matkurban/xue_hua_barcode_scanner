import 'package:material_ui/material_ui.dart';

import '../../models/barcode_enums.dart';
import '../../models/scanner_state.dart';
import '../../models/scanner_texts.dart';
import '../scanner_builders.dart';
import 'scanner_bottom_action_button.dart';

/// WeChat Scan-style bottom section containing the centered prompt caption
/// ("扫二维码 / 条码" or "轻触小绿点，选择要识别的码") and floating circular
/// Torch & Gallery buttons.
class ScannerBottomBar extends StatelessWidget {
  const ScannerBottomBar({
    super.key,
    required this.state,
    required this.texts,
    required this.cornerColor,
    required this.errorColor,
    required this.hideTorchWhenUnavailable,
    required this.hideBottomBarOnMultiSelect,
    required this.hintTextBuilder,
    required this.bottomBarBuilder,
    required this.torchButtonBuilder,
    required this.galleryButtonBuilder,
    required this.onToggleTorch,
    required this.onPickGallery,
  });

  final ScannerState state;
  final XueHuaScannerTexts texts;
  final Color cornerColor;
  final Color errorColor;
  final bool hideTorchWhenUnavailable;
  final bool hideBottomBarOnMultiSelect;
  final XueHuaHintTextBuilder? hintTextBuilder;
  final XueHuaBottomBarBuilder? bottomBarBuilder;
  final XueHuaTorchButtonBuilder? torchButtonBuilder;
  final XueHuaGalleryButtonBuilder? galleryButtonBuilder;
  final VoidCallback onToggleTorch;
  final VoidCallback onPickGallery;

  @override
  Widget build(BuildContext context) {
    final Widget hintWidget = _buildHintWidget(context);

    if (bottomBarBuilder != null) {
      return RepaintBoundary(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Center(child: hintWidget),
            ),
            const SizedBox(height: 16),
            bottomBarBuilder!(context, state, onToggleTorch, onPickGallery),
          ],
        ),
      );
    }

    final bool hideActionRow =
        state.isSelectingMultiBarcode && hideBottomBarOnMultiSelect;

    final Widget torchButton = torchButtonBuilder != null
        ? torchButtonBuilder!(context, state, onToggleTorch)
        : ScannerBottomActionButton(
            key: const ValueKey<String>('xh_scanner_torch_button'),
            icon: state.isTorchOn
                ? Icons.flashlight_on_rounded
                : Icons.flashlight_off_rounded,
            label: state.isTorchOn ? texts.torchOnLabel : texts.torchOffLabel,
            isActive: state.isTorchOn,
            isEnabled: state.hasTorch,
            activeColor: cornerColor,
            onTap: onToggleTorch,
          );

    final Widget galleryButton = galleryButtonBuilder != null
        ? galleryButtonBuilder!(context, state, onPickGallery)
        : ScannerBottomActionButton(
            key: const ValueKey<String>('xh_scanner_gallery_button'),
            icon: Icons.photo_library_rounded,
            label: texts.galleryLabel,
            isActive: false,
            isEnabled: true,
            activeColor: cornerColor,
            onTap: onPickGallery,
          );

    final bool hideTorch = hideTorchWhenUnavailable && !state.hasTorch;

    return RepaintBoundary(
      child: Padding(
        padding: const EdgeInsets.only(left: 44, right: 44, bottom: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Center(child: hintWidget),
            if (!hideActionRow) ...<Widget>[
              const SizedBox(height: 24),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 280),
                child: Row(
                  mainAxisAlignment: hideTorch
                      ? MainAxisAlignment.center
                      : MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    if (!hideTorch) torchButton,
                    galleryButton,
                  ],
                ),
              ),
            ] else
              const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildHintWidget(BuildContext context) {
    if (hintTextBuilder != null) {
      return hintTextBuilder!(context, state);
    }

    final bool isError = state.hasValidationError;
    final bool isMultiSelect = state.isSelectingMultiBarcode;

    final String displayPrompt;
    if (isError) {
      displayPrompt =
          state.lastGalleryScanStatus == GalleryScanStatus.noBarcodeFound
          ? texts.noBarcodeInImageText
          : texts.invalidBarcodeText;
    } else if (isMultiSelect) {
      displayPrompt = texts.multiBarcodeHintText;
    } else {
      displayPrompt = texts.hintText;
    }

    if (isError) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: errorColor.withValues(alpha: 0.24),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: errorColor.withValues(alpha: 0.82)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.error_outline_rounded, color: errorColor, size: 16),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                displayPrompt,
                key: const ValueKey<String>('xh_scanner_hint'),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: errorColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: isMultiSelect
            ? const Color(0x73000000)
            : const Color(0x33000000),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        displayPrompt,
        key: const ValueKey<String>('xh_scanner_hint'),
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Color(0xEBFFFFFF),
          fontSize: 14,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.4,
          shadows: <Shadow>[
            Shadow(
              color: Color(0x99000000),
              blurRadius: 6,
              offset: Offset(0, 1),
            ),
          ],
        ),
      ),
    );
  }
}
