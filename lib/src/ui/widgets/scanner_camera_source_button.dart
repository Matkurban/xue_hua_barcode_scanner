import 'package:chat_context_menu/chat_context_menu.dart';
import 'package:material_ui/material_ui.dart';

import '../../models/barcode_enums.dart';
import '../../models/camera_input_source.dart';
import 'circle_glass_icon_button.dart';

/// Top-bar control that lets the user pick a camera when several exist.
///
/// A single input source builds nothing, so the scanner never shows or opens
/// an empty menu. The menu opens only after the user taps the button.
class XueHuaCameraSourceButton extends StatelessWidget {
  /// Creates a camera input-source button.
  const XueHuaCameraSourceButton({
    super.key,
    required this.sources,
    required this.activeSourceId,
    required this.tooltip,
    required this.onSelected,
  });

  /// Available cameras. The button is omitted when this has fewer than two items.
  final List<CameraInputSource> sources;

  /// Identifier of the camera that is currently previewing.
  final String activeSourceId;

  /// Tooltip on the anchor button.
  final String tooltip;

  /// Called after the user picks a different input source.
  final ValueChanged<CameraInputSource> onSelected;

  @override
  Widget build(BuildContext context) {
    if (sources.length <= 1) {
      return const SizedBox.shrink();
    }

    return ChatContextMenuWrapper(
      topPadding: 0,
      backgroundColor: const Color(0xFF1C1C1E),
      borderRadius: BorderRadius.circular(12),
      padding: const EdgeInsets.symmetric(vertical: 4),
      barrierColor: const Color(0x66000000),
      excludeAnchorFromBarrier: true,
      barrierAnchorBorderRadius: BorderRadius.circular(24),
      menuConstraints: const BoxConstraints(minWidth: 196, maxWidth: 280),
      shadows: const <BoxShadow>[
        BoxShadow(
          color: Color(0x66000000),
          blurRadius: 24,
          offset: Offset(0, 8),
        ),
      ],
      menuBuilder: (BuildContext context, VoidCallback hideMenu) {
        return Material(
          type: MaterialType.transparency,
          child: Column(
            key: const ValueKey<String>('xh_scanner_camera_menu'),
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              for (final (int index, CameraInputSource source)
                  in sources.indexed)
                KeyedSubtree(
                  key: ValueKey<String>('xh_scanner_camera_menu_item_$index'),
                  child: _CameraSourceMenuItem(
                    source: source,
                    selected: source.id == activeSourceId,
                    onTap: () {
                      hideMenu();
                      onSelected(source);
                    },
                  ),
                ),
            ],
          ),
        );
      },
      widgetBuilder:
          (BuildContext context, VoidCallback showMenu, VoidCallback _) {
            return CircleGlassIconButton(
              key: const ValueKey<String>('xh_scanner_switch_camera_button'),
              icon: Icons.cameraswitch_rounded,
              tooltip: tooltip,
              onPressed: showMenu,
            );
          },
    );
  }
}

class _CameraSourceMenuItem extends StatelessWidget {
  const _CameraSourceMenuItem({
    required this.source,
    required this.selected,
    required this.onTap,
  });

  final CameraInputSource source;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color color = selected ? const Color(0xFF00E676) : Colors.white;
    final IconData icon = switch (source.facing) {
      CameraFacing.front => Icons.camera_front_outlined,
      CameraFacing.external => Icons.videocam_outlined,
      CameraFacing.back => Icons.camera_rear_outlined,
    };
    return GestureDetector(
      key: ValueKey<String>('xh_scanner_camera_source_${source.id}'),
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: <Widget>[
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                source.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: color, fontSize: 14),
              ),
            ),
            if (selected)
              const Icon(
                Icons.check_rounded,
                color: Color(0xFF00E676),
                size: 18,
              ),
          ],
        ),
      ),
    );
  }
}
