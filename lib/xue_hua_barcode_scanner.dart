/// A 6-platform (Android, iOS, macOS, Windows, Linux, Web) Flutter Barcode &
/// QR Code recognition, generation, and real-time camera scanner plugin powered
/// by `zxing-cpp` FFI & WebAssembly (`dart:js_interop`).
///
/// Author: Matkurban <3496354336@qq.com>
/// Repository: https://github.com/Matkurban/xue_hua_barcode_scanner
library xue_hua_barcode_scanner;

export 'src/controller/scanner_controller.dart';
export 'src/core/scanner_engine_interface.dart';
export 'src/models/barcode_models.dart';
export 'src/ui/barcode_scanner_page.dart';
export 'src/ui/scanner_overlay.dart';
