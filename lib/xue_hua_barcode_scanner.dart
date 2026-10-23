/// A 6-platform (Android, iOS, macOS, Windows, Linux, Web) Flutter Barcode &
/// QR Code recognition, generation, and real-time camera scanner plugin powered
/// by `zxing-cpp` 3.1.1 FFI & WebAssembly (`dart:js_interop`).
///
/// Author: Matkurban <3496354336@qq.com>
/// Repository: https://github.com/Matkurban/xue_hua_barcode_scanner
library;

export 'src/controller/barcode_scanner.dart';
export 'src/controller/scanner_controller.dart';
export 'src/core/scanner_engine_interface.dart';
export 'src/models/barcode_enums.dart';
export 'src/models/barcode_models.dart';
export 'src/models/barcode_result.dart';
export 'src/models/camera_frame_packet.dart';
export 'src/models/scanner_state.dart';
export 'src/models/scanner_texts.dart';
export 'src/ui/barcode_scanner_page.dart';
export 'src/ui/corner_anchor_highlight.dart';
export 'src/ui/scan_line_animation.dart';
export 'src/ui/scanner_builders.dart';
export 'src/ui/scanner_overlay.dart';
export 'src/ui/scanner_view.dart';
