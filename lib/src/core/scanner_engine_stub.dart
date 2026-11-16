import 'scanner_engine_interface.dart';

/// Stub factory overridden by conditional imports (`scanner_ffi.dart` or `scanner_web.dart`).
ScannerPlatformEngine createPlatformScannerEngine() {
  throw UnsupportedError(
    'Cannot create ScannerPlatformEngine without dart:ffi or dart:js_interop.',
  );
}
