import 'package:material_ui/material_ui.dart';

import '../../models/scanner_state.dart';
import '../../models/scanner_texts.dart';
import '../scanner_builders.dart';
import 'scanner_bottom_action_button.dart';

/// Bottom action bar of the scanner view containing the Torch and Gallery buttons.
class ScannerBottomBar extends StatelessWidget {
  const ScannerBottomBar({
    super.key,
    required this.state,
    required this.texts,
    required this.cornerColor,
    required this.hideTorchWhenUnavailable,
    required this.bottomBarBuilder,
    required this.torchButtonBuilder,
    required this.galleryButtonBuilder,
    required this.onToggleTorch,
    required this.onPickGallery,
  });

  final ScannerState state;
  final XueHuaScannerTexts texts;
  final Color cornerColor;
  final bool hideTorchWhenUnavailable;
  final XueHuaBottomBarBuilder? bottomBarBuilder;
  final XueHuaTorchButtonBuilder? torchButtonBuilder;
  final XueHuaGalleryButtonBuilder? galleryButtonBuilder;
  final VoidCallback onToggleTorch;
  final VoidCallback onPickGallery;

  @override
  Widget build(BuildContext context) {
    if (bottomBarBuilder != null) {
      return bottomBarBuilder!(context, state, onToggleTorch, onPickGallery);
    }

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

    return Padding(
      padding: const EdgeInsets.only(left: 48, right: 48, bottom: 36),
      child: Row(
        mainAxisAlignment: hideTorch
            ? MainAxisAlignment.center
            : MainAxisAlignment.spaceBetween,
        children: <Widget>[if (!hideTorch) torchButton, galleryButton],
      ),
    );
  }
}
