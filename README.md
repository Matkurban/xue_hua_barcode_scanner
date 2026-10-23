[English](README.md) | [简体中文](README_ZH.md)

# xue_hua_barcode_scanner

A production-grade, 6-platform (**Android, iOS, macOS, Windows, Linux, Web**) Flutter Barcode & QR Code recognition, generation, and real-time camera scanner plugin powered by **`zxing-cpp`** (C++20 FFI) and **`zxing-wasm`** (`dart:js_interop`).

- **Version**: `1.0.0`
- **Author**: Matkurban <3496354336@qq.com>
- **Repository**: [https://github.com/Matkurban/xue_hua_barcode_scanner](https://github.com/Matkurban/xue_hua_barcode_scanner)
- **Implementation Plan**: [Architecture & Implementation Plan (IMPLEMENTATION_PLAN.md)](IMPLEMENTATION_PLAN.md)

## Installation (pub.dev)

Add `xue_hua_barcode_scanner` from `pub.dev` by running:

```bash
flutter pub add xue_hua_barcode_scanner
```

Or add it directly to your `pubspec.yaml`:

```yaml
dependencies:
  xue_hua_barcode_scanner: ^1.0.0
```

## Platform Support Matrix

| Platform | Engine Architecture | Camera Stream & Preview | Torch / Flashlight | Front / Back Camera Switch | Gallery Image Decode |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Android** | `dart:ffi` + `zxing-cpp` (CMake C++20) | YUV420 (`yPlane` `rowStride`) / Texture | Supported | Supported (Back / Front) | Supported |
| **iOS** | `dart:ffi` + `zxing-cpp` (SwiftPM / Podspec C++20) | CoreVideo `BGRA8888` / Texture | Supported | Supported (Back / Front) | Supported |
| **macOS** | `dart:ffi` + `zxing-cpp` (SwiftPM / Podspec C++20) | AVFoundation / USB UVC | Graceful fallback (`unavailable`) | Built-in / External USB | Supported |
| **Windows** | `dart:ffi` + `zxing-cpp` (CMake C++20) | MediaFoundation / USB UVC | Graceful fallback (`unavailable`) | Built-in / External USB | Supported |
| **Linux** | `dart:ffi` + `zxing-cpp` (CMake C++20) | V4L2 / PipeWire | Graceful fallback (`unavailable`) | Built-in / External USB | Supported |
| **Web** | `dart:js_interop` + `zxing-wasm` / `BarcodeDetector` | `getUserMedia` + `HtmlElementView` | Mobile Web `applyConstraints({torch})` | `facingMode: user / environment` | File input (`image/*`) |

## Key Features

1. **Unified `zxing-cpp` Decoding & Generation Core**:
   - **5 Native Platforms**: Compiles `zxing-cpp` (`v3.1.1`) via CMake `FetchContent`, Swift Package Manager (`Package.swift`), and CocoaPods C++20, bridged through an `extern "C"` wrapper (`src/zxing_ffi_bridge.h`) and executed inside background `Isolate.run` workers with deterministic native heap deallocation (`free_barcode_results`, `free_encoded_barcode_image`).
   - **Web Platform**: Isolates `dart:ffi` via conditional imports and uses modern `dart:js_interop` to bridge `zxing-wasm` and the browser's `BarcodeDetector` API with 100% identical Dart APIs.
2. **Zero-Copy Y-Plane & `rowStride` Alignment**:
   - Directly decodes single-channel grayscale (`PixelFormat.lum` for Android `YUV_420_888` / `NV21` Y-plane), `PixelFormat.rgba8888`, `PixelFormat.bgra8888`, and `PixelFormat.rgb888` while normalizing hardware row alignment padding (`rowStride`) to prevent diagonal image skew.
3. **Out-of-the-Box & 100% Customizable `XueHuaBarcodeScannerPage`**:
   - Full-screen aspect-ratio-preserving camera preview, semi-transparent rounded-square cutout overlay with 4 glowing corner brackets, smooth looping green laser scan line, top bar with Back button, `"将二维码放入框内"` prompt, and Front/Back camera flip button, bottom symmetric **Torch** and **Gallery** buttons, and real-time green anchor highlights on detected `cornerPoints`.
   - Every visual component can be overridden via `overlayBuilder`, `scanLineBuilder`, `topBarBuilder`, `hintTextBuilder`, `bottomBarBuilder`, `torchButtonBuilder`, and `galleryButtonBuilder`.

## Platform Configuration & Permissions

### 1. Android (`android/app/src/main/AndroidManifest.xml`)
```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-feature android:name="android.hardware.camera" android:required="false" />
<uses-feature android:name="android.hardware.camera.autofocus" android:required="false" />
```

### 2. iOS (`ios/Runner/Info.plist`)
```xml
<key>NSCameraUsageDescription</key>
<string>Camera access is required to scan barcodes and QR codes.</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>Photo library access is required to recognize barcodes from saved images.</string>
```

### 3. macOS (`macos/Runner/Info.plist` & Entitlements)
Add `NSCameraUsageDescription` to `macos/Runner/Info.plist`, and enable camera access in both `macos/Runner/DebugProfile.entitlements` and `macos/Runner/Release.entitlements`:
```xml
<key>com.apple.security.device.camera</key>
<true/>
```

### 4. Windows & Linux
- **Windows**: Requires Visual Studio 2022 with the "Desktop development with C++" workload (MSVC C++20 & CMake 3.16+).
- **Linux**: Requires `clang` / `g++` (C++20), `cmake`, `ninja-build`, and `pkg-config`.

### 5. Web (`web/index.html`)
Camera streaming (`navigator.mediaDevices.getUserMedia`) and mobile browser torch control require `https://` or `http://localhost`. Add `zxing-wasm` to `web/index.html` for full WebAssembly decoding across all browsers:
```html
<script src="https://cdn.jsdelivr.net/npm/zxing-wasm@3.1.1/dist/iife/full/index.js"></script>
```

## Quick Start

### 1. Open the Standard Barcode Scanner Page
```dart
import 'package:flutter/material.dart';
import 'package:xue_hua_barcode_scanner/xue_hua_barcode_scanner.dart';

Future<void> scanBarcode(BuildContext context) async {
  final List<BarcodeResult>? results = await Navigator.of(context).push(
    MaterialPageRoute<List<BarcodeResult>>(
      builder: (_) => const XueHuaBarcodeScannerPage(
        autoPopOnDetect: true,
        hintText: '将二维码放入框内',
      ),
    ),
  );

  if (results != null && results.isNotEmpty) {
    final BarcodeResult first = results.first;
    debugPrint('Text: ${first.text}, Corners: ${first.cornerPoints}');
  }
}
```

### 2. Full UI Customization with Builders & `XueHuaScannerController`
```dart
final controller = XueHuaScannerController(
  initialFacing: CameraFacing.back,
);

XueHuaBarcodeScannerPage(
  controller: controller,
  overlayBuilder: (context, scanWindow, state) => XueHuaScannerOverlay(
    scanWindow: scanWindow,
    cornerColor: Colors.cyanAccent,
    borderRadius: 24,
  ),
  scanLineBuilder: (context, animation, scanWindow) => XueHuaScanLineAnimation(
    animation: animation,
    scanWindow: scanWindow,
    lineColor: Colors.cyanAccent,
  ),
  hintTextBuilder: (context, state) => const Text(
    '将二维码放入框内',
    style: TextStyle(color: Colors.cyanAccent, fontSize: 15),
  ),
  torchButtonBuilder: (context, state, onToggleTorch) => IconButton(
    icon: Icon(state.isTorchOn ? Icons.flash_on : Icons.flash_off),
    onPressed: onToggleTorch,
  ),
  galleryButtonBuilder: (context, state, onPickGallery) => IconButton(
    icon: const Icon(Icons.photo_library),
    onPressed: onPickGallery,
  ),
);
```

### 3. Direct Image Decoding & Barcode Generation
```dart
// Encode text into a PNG barcode image
final Uint8List pngBytes = await XueHuaBarcodeScanner.encodeBarcode(
  'https://github.com/Matkurban/xue_hua_barcode_scanner',
  width: 512,
  height: 512,
  margin: 2,
  eccLevel: BarcodeEccLevel.high,
);

// Decode from PNG/JPG bytes or file path
final List<BarcodeResult> decodedFromMemory =
    await XueHuaBarcodeScanner.decodeImageMemory(pngBytes);
final List<BarcodeResult> decodedFromFile =
    await XueHuaBarcodeScanner.decodeImageFile('/path/to/barcode.png');

// Decode raw camera Y-plane or RGBA8888 bytes with rowStride alignment
final List<BarcodeResult> decodedFromBytes =
    await XueHuaBarcodeScanner.decodeImageBytes(
  rawYPlaneBytes,
  width: 1280,
  height: 720,
  rowStride: 1280,
  format: PixelFormat.lum,
  tryHarder: true,
  tryRotate: true,
  tryInvert: true,
);
```

## `XueHuaScannerController` API Overview

| Method / Property | Description |
| :--- | :--- |
| `ValueListenable<ScannerState> stateListenable` | Listens to `isInitialized`, `isRunning`, `isPaused`, `torchState`, `cameraFacing`, and `latestResults`. |
| `Future<void> start()` / `stop()` | Starts or stops the platform camera stream. |
| `Future<void> pause()` / `resume()` | Pauses or resumes real-time frame decoding and scan line animation. |
| `Future<bool> toggleTorch()` | Toggles hardware flashlight on Android, iOS, and mobile Web; returns `false` on unsupported desktop cameras. |
| `Future<void> switchCamera()` | Switches between rear (`CameraFacing.back`) and front (`CameraFacing.front`) cameras. |
| `Future<List<BarcodeResult>> analyzeImageFromGallery()` | Picks an image from the local gallery/filesystem and decodes barcodes. |

## License

See [LICENSE](LICENSE) for full license terms.
