import 'scanner_engine_interface.dart';

/// Stub factory overridden by conditional imports (`scanner_ffi.dart` or `scanner_web.dart`).
XueHuaScannerPlatformEngine createPlatformScannerEngine() {
  throw UnsupportedError(
    'Cannot create XueHuaScannerPlatformEngine without dart:ffi or dart:js_interop.',
  );
}
