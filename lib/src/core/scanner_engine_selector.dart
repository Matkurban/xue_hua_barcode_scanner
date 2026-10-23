export 'scanner_engine_stub.dart'
    if (dart.library.ffi) '../ffi/scanner_ffi.dart'
    if (dart.library.js_interop) '../web/scanner_web.dart';
