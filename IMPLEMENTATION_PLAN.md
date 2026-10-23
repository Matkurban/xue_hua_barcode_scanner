[English](IMPLEMENTATION_PLAN.md) | [简体中文](IMPLEMENTATION_PLAN_ZH.md)

# Implementation Plan — `xue_hua_barcode_scanner` (v1.0.0)

- **Package Name**: `xue_hua_barcode_scanner`
- **Version**: `1.0.0`
- **Author**: Matkurban <3496354336@qq.com>
- **Repository**: [https://github.com/Matkurban/xue_hua_barcode_scanner](https://github.com/Matkurban/xue_hua_barcode_scanner)
- **Back to README**: [English README (README.md)](README.md)

## 1. Architecture Overview

`xue_hua_barcode_scanner` provides a unified 6-platform (**Android, iOS, macOS, Windows, Linux, Web**) barcode and 2D code recognition, generation, and real-time camera scanning architecture built on **`zxing-cpp`**:

1. **5 Native Platforms (Android, iOS, macOS, Windows, Linux)**:
   - Compiles `zxing-cpp` (`v3.1.1`, C++20) into a native library and exposes a C ABI wrapper (`src/zxing_ffi_bridge.h` / `src/zxing_ffi_bridge.cpp`).
   - Invokes native decoding (`zxing_decode_image_bytes`) and encoding (`zxing_encode_barcode`) inside background worker isolates (`Isolate.run`) via `dart:ffi`, freeing all native heap allocations (`free_barcode_results`, `free_encoded_barcode_image`) inside `finally` blocks.
2. **Web Platform**:
   - Uses conditional exports (`lib/src/core/scanner_engine_selector.dart`) to isolate `dart:ffi` from Web builds.
   - Uses `dart:js_interop` and `dart:ui_web` (`lib/src/web/scanner_web.dart`) to bridge `zxing-wasm` and the browser's `BarcodeDetector` API while exposing 100% identical Dart APIs (`XueHuaBarcodeScanner`, `XueHuaScannerController`, `XueHuaBarcodeScannerPage`, `XueHuaScannerView`).

## 2. Module Breakdown & Naming Conventions

All public and internal files, classes, and C symbols consistently use the `barcode` naming convention:

| Layer | File Path | Key Classes / Symbols |
| :--- | :--- | :--- |
| **Public Entry** | `lib/xue_hua_barcode_scanner.dart` | Exports models, controller, engine interface, and UI components |
| **Data Models** | `lib/src/models/barcode_models.dart` | `BarcodeResult`, `BarcodeFormat`, `BarcodeEccLevel`, `PixelFormat`, `CameraFacing`, `TorchState`, `ScannerState`, `CameraFramePacket` |
| **C/C++20 Bridge** | `src/zxing_ffi_bridge.h`, `src/zxing_ffi_bridge.cpp` | `CBarcodePoint`, `CBarcodeResult`, `CBarcodeResultList`, `CEncodedBarcodeImage`, `zxing_decode_image_bytes`, `free_barcode_results`, `zxing_encode_barcode`, `free_encoded_barcode_image` |
| **FFI Worker Engine** | `lib/src/ffi/zxing_ffi_bindings.dart`, `lib/src/ffi/scanner_ffi.dart` | `ZxingFfiBindings`, `XueHuaScannerFfiEngine`, `normalizeRowStrideBuffer` |
| **Web Interop Engine** | `lib/src/web/scanner_web.dart` | `XueHuaBarcodeScannerWeb` (`getUserMedia`, `applyConstraints({torch})`, `ZXingWasm`, `BarcodeDetector`) |
| **Controller & API** | `lib/src/controller/scanner_controller.dart` | `XueHuaBarcodeScanner`, `XueHuaScannerController` |
| **UI Components** | `lib/src/ui/scanner_overlay.dart`, `lib/src/ui/barcode_scanner_page.dart` | `XueHuaBarcodeScannerPage`, `XueHuaScannerView`, `XueHuaScannerOverlay`, `XueHuaScanLineAnimation`, `XueHuaCornerAnchorHighlight` |

## 3. Six-Platform Build & Camera Stream Adaptation

- **CMake (Android, Windows, Linux)**: Configured in `CMakeLists.txt` and `src/CMakeLists.txt` (`VERSION 1.0.0`, `CMAKE_CXX_STANDARD 20`, `FetchContent` for `zxing-cpp` `v3.1.1`, `ZXING_EXAMPLES OFF`, `ZXING_UNIT_TESTS OFF`, Android 16KB page size alignment).
- **CocoaPods (iOS, macOS)**: Configured in `ios/xue_hua_barcode_scanner.podspec` and `macos/xue_hua_barcode_scanner.podspec` (`s.version = '1.0.0'`, `CLANG_CXX_LANGUAGE_STANDARD = 'c++20'`, `-Wl,-exported_symbol` flags preventing symbol stripping in Release archives).
- **Row Stride & Sensor Orientation**: `normalizeRowStrideBuffer` handles padded `rowStride` rows in Android `YUV_420_888` (`PixelFormat.lum`) and iOS/macOS CoreVideo `BGRA8888` buffers; `BarcodeResult.mapCornersToViewport` maps detected corner coordinates across `0°/90°/180°/270°` sensor orientations and front-camera mirroring.
- **Desktop & Web Graceful Fallbacks**: Desktop platforms without rear flash automatically report `TorchState.unavailable`; Web uses `MediaStreamTrack.getCapabilities()` and `applyConstraints({advanced: [{torch: true}]})` on supported mobile browsers.
