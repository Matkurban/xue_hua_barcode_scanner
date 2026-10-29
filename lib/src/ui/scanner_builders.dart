import 'package:material_ui/material_ui.dart';

import '../models/scanner_state.dart';

/// Builder signature for customizing the semi-transparent mask and scan cutout box.
typedef XueHuaOverlayBuilder = Widget Function(
  BuildContext context,
  Rect scanWindow,
  ScannerState state,
);

/// Builder signature for customizing the animated scan line inside [scanWindow].
typedef XueHuaScanLineBuilder = Widget Function(
  BuildContext context,
  Animation<double> animation,
  Rect scanWindow,
);

/// Builder signature for customizing the top navigation bar (Back button,
/// centered hint title, and Front/Back camera switch button).
typedef XueHuaTopBarBuilder = Widget Function(
  BuildContext context,
  ScannerState state,
  VoidCallback onBack,
  VoidCallback onSwitchCamera,
);

/// Builder signature for customizing the prompt text.
typedef XueHuaHintTextBuilder = Widget Function(
  BuildContext context,
  ScannerState state,
);

/// Builder signature for customizing the entire bottom action bar.
typedef XueHuaBottomBarBuilder = Widget Function(
  BuildContext context,
  ScannerState state,
  VoidCallback onToggleTorch,
  VoidCallback onPickGallery,
);

/// Builder signature for customizing the Torch / Flashlight toggle button.
typedef XueHuaTorchButtonBuilder = Widget Function(
  BuildContext context,
  ScannerState state,
  VoidCallback onToggleTorch,
);

/// Builder signature for customizing the Gallery image picker button.
typedef XueHuaGalleryButtonBuilder = Widget Function(
  BuildContext context,
  ScannerState state,
  VoidCallback onPickGallery,
);

/// Builder signature for customizing the dedicated camera permission-denied view.
typedef XueHuaPermissionDeniedBuilder = Widget Function(
  BuildContext context,
  ScannerState state,
  VoidCallback onOpenSettings,
  VoidCallback onRetryPermission,
  VoidCallback onPickGallery,
);
