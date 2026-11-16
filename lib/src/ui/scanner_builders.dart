import 'package:material_ui/material_ui.dart';

import '../models/barcode_result.dart';
import '../models/scanner_state.dart';

/// Controls how a custom or default barcode marker widget is positioned
/// relative to its detected barcode geometry in the scanner viewport.
enum BarcodeMarkerAlignment {
  /// Centers the marker widget at [BarcodeMarkerInfo.center] regardless of
  /// the marker widget's own width and height (ideal for circular anchor dots,
  /// floating pills, or callout badges).
  center,

  /// Positions and sizes the marker widget directly to [BarcodeMarkerInfo.boundingBox]
  /// (ideal for drawing custom bounding boxes or frame overlays that wrap the barcode).
  boundingBox,
}

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

/// Builder signature for customizing the top navigation bar (Back/Close button,
/// optional cancel button in multi-barcode mode, and camera switch button).
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

/// Builder signature for customizing the interactive widget placed at each
/// detected barcode's exact viewport position (`info.center` / `info.boundingBox`).
///
/// Invoke [onSelect] when the user taps the custom widget to select `info.result`.
typedef XueHuaBarcodeMarkerBuilder = Widget Function(
  BuildContext context,
  BarcodeMarkerInfo info,
  VoidCallback onSelect,
);

/// Builder signature for customizing the entire overlay shown when multiple
/// barcodes are detected and the camera preview is frozen for manual selection.
typedef XueHuaMultiBarcodeOverlayBuilder = Widget Function(
  BuildContext context,
  ScannerState state,
  List<BarcodeMarkerInfo> markers,
  ValueChanged<BarcodeResult> onSelectBarcode,
  VoidCallback onCancel,
);
