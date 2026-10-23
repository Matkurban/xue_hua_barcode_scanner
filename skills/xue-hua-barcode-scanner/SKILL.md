---
name: xue-hua-barcode-scanner
description: Use when integrating or working with xue_hua_barcode_scanner APIs to configure platform permissions, scan barcodes or QR codes in real time, customize XueHuaBarcodeScannerPage or XueHuaScannerView UI builders, control camera torch/facing via XueHuaScannerController, or decode/encode barcodes using zxing-cpp 3.1.1 FFI and WebAssembly across Android, iOS, macOS, Windows, Linux, and Web.
---
# xue-hua-barcode-scanner

Provide complete 6-platform integration tutorials, permission configurations, UI customization builders, controller lifecycle management, and `zxing-cpp 3.1.1` FFI/Wasm usage patterns for the `xue_hua_barcode_scanner` Flutter plugin (`https://github.com/Matkurban/xue_hua_barcode_scanner`).

## Environment & UI Package Conventions

- **SDK Constraints**: Dart `^3.13.0`, Flutter `>=3.47.0`
- **UI Import**: Use `import 'package:material_ui/material_ui.dart';` instead of `package:flutter/material.dart`.

## When to Use

- Integrating `xue_hua_barcode_scanner` into a Flutter project and configuring camera/gallery permissions across Android, iOS, macOS, Windows, Linux, and Web
- Opening a ready-to-use full-screen barcode scanner page (`XueHuaBarcodeScannerPage`) or embedding a camera scanner view (`XueHuaScannerView`)
- Customizing any scanner UI element (`overlayBuilder`, `scanLineBuilder`, `topBarBuilder`, `hintTextBuilder`, `bottomBarBuilder`, `torchButtonBuilder`, `galleryButtonBuilder`)
- Programmatically controlling the flashlight/torch (`toggleTorch`), switching front/back/external cameras (`switchCamera`), pausing/resuming streams (`pause`, `resume`), or picking an image from the photo gallery (`analyzeImageFromGallery`) via `XueHuaScannerController`
- Decoding barcodes / QR codes directly from raw camera planes (`decodeImageBytes` with `PixelFormat.lum` / `rgba8888` / `bgra8888` and `rowStride`), local image files (`decodeImageFile`), or compressed PNG/JPEG bytes (`decodeImageMemory`)
- Generating barcode PNG images (`encodeBarcode`) with configurable dimensions, margin, and `BarcodeEccLevel`

## Step-by-Step Integration & Permissions Checklist

Always verify and configure the required platform permissions before launching `XueHuaBarcodeScannerPage` or calling `controller.start()`:

### 1. `pubspec.yaml` Setup
```yaml
environment:
  sdk: ^3.13.0
  flutter: '>=3.47.0'

dependencies:
  flutter:
    sdk: flutter
  material_ui: ^1.8.0
  xue_hua_barcode_scanner: ^1.0.0
```

### 2. Android (`android/app/src/main/AndroidManifest.xml`)
- **Required Permission**: `android.permission.CAMERA` (runtime permission is automatically requested by `XueHuaBarcodeScannerPlugin` when `startCamera` is called).
- **Gallery Picker**: Uses `Intent.ACTION_GET_CONTENT` (`image/*`), so no storage permissions (`READ_EXTERNAL_STORAGE` / `READ_MEDIA_IMAGES`) are needed.
```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-permission android:name="android.permission.CAMERA" />
    <uses-feature android:name="android.hardware.camera" android:required="false" />
    <uses-feature android:name="android.hardware.camera.autofocus" android:required="false" />
    ...
</manifest>
```

### 3. iOS (`ios/Runner/Info.plist`)
- **Required Keys**: Both `NSCameraUsageDescription` and `NSPhotoLibraryUsageDescription` must be present in `ios/Runner/Info.plist`:
```xml
<key>NSCameraUsageDescription</key>
<string>需要使用相机以实时扫描条形码和二维码。</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>需要访问相册以从本地图片中识别条形码和二维码。</string>
```
- Supports both **Swift Package Manager (`ios/xue_hua_barcode_scanner/Package.swift`)** and **CocoaPods (`ios/xue_hua_barcode_scanner.podspec`)** (iOS `13.0+`).

### 4. macOS (`macos/Runner/Info.plist` + Entitlements)
- **Step A (`macos/Runner/Info.plist`)**: Add `NSCameraUsageDescription` and `NSPhotoLibraryUsageDescription`.
```xml
<key>NSCameraUsageDescription</key>
<string>需要使用摄像头以实时扫描条形码和二维码。</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>需要访问本地图片以识别条形码和二维码。</string>
```
- **Step B (`macos/Runner/DebugProfile.entitlements` & `macos/Runner/Release.entitlements`)**: Enable `com.apple.security.device.camera` (mandatory for App Sandbox camera access) and `com.apple.security.files.user-selected.read-only` (for `NSOpenPanel` image selection):
```xml
<key>com.apple.security.device.camera</key>
<true/>
<key>com.apple.security.files.user-selected.read-only</key>
<true/>
```
- Supports both **Swift Package Manager (`macos/xue_hua_barcode_scanner/Package.swift`)** and **CocoaPods (`macos/xue_hua_barcode_scanner.podspec`)** (macOS `10.15+`).

### 5. Windows & Linux
- **Windows**: Ensure Windows camera privacy settings allow desktop apps to access the camera (`Settings -> Privacy & security -> Camera`). Requires Visual Studio 2022 C++20 workload and CMake `3.16+`.
- **Linux**: Ensure the user has access to `/dev/video*` (`video` group) and `libgtk-3-dev`, `clang`/`g++` (C++20), `cmake` (`3.16+`), and `ninja-build` are installed.

### 6. Web (`web/index.html`)
- Must run under `https://` or `http://localhost` for `navigator.mediaDevices.getUserMedia` and mobile torch (`applyConstraints`).
- Add `zxing-wasm` (`3.1.1`) in `web/index.html`:
```html
<script src="https://cdn.jsdelivr.net/npm/zxing-wasm@3.1.1/dist/iife/full/index.js"></script>
```

---

## Code Usage Patterns

### 1. Launch Default `XueHuaBarcodeScannerPage`

```dart
import 'package:material_ui/material_ui.dart';
import 'package:xue_hua_barcode_scanner/xue_hua_barcode_scanner.dart';

Future<void> openDefaultScanner(BuildContext context) async {
  final List<BarcodeResult>? results = await Navigator.of(context).push(
    MaterialPageRoute<List<BarcodeResult>>(
      builder: (_) => const XueHuaBarcodeScannerPage(
        autoPopOnDetect: true,
        hintText: '将二维码放入框内',
      ),
    ),
  );
  if (results != null && results.isNotEmpty) {
    debugPrint('Scanned barcode text: ${results.first.text}');
  }
}
```

### 2. Control Torch, Camera Facing & Gallery via `XueHuaScannerController`

1. Instantiate `XueHuaScannerController` inside `State.initState()` and pass it to `XueHuaBarcodeScannerPage` or `XueHuaScannerView`.
2. Listen to `controller` (`ValueListenable<ScannerState>`) via `ValueListenableBuilder<ScannerState>` to inspect `state.isTorchOn`, `state.hasTorch`, `state.cameraFacing`, and `state.latestResults`.
3. Call `controller.toggleTorch()`, `controller.switchCamera()`, `controller.pause()`, `controller.resume()`, or `controller.analyzeImageFromGallery()`.
4. Always dispose externally created controllers in `State.dispose()` (placed as the last method of the `State` class).

### 3. Customize UI with Builders

```dart
XueHuaBarcodeScannerPage(
  controller: controller,
  overlayBuilder: (context, scanWindow, state) {
    return XueHuaScannerOverlay(
      scanWindow: scanWindow,
      cornerColor: Colors.cyanAccent,
      borderRadius: 24,
      maskColor: Colors.black.withValues(alpha: 0.72),
    );
  },
  scanLineBuilder: (context, animation, scanWindow) {
    return XueHuaScanLineAnimation(
      animation: animation,
      scanWindow: scanWindow,
      lineColor: Colors.cyanAccent,
    );
  },
  hintTextBuilder: (context, state) => const Text(
    '将二维码放入框内',
    style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold),
  ),
  torchButtonBuilder: (context, state, onToggleTorch) => IconButton(
    icon: Icon(
      state.isTorchOn ? Icons.flash_on : Icons.flash_off,
      color: state.isTorchOn ? Colors.amber : Colors.white,
    ),
    onPressed: onToggleTorch,
  ),
  galleryButtonBuilder: (context, state, onPickGallery) => IconButton(
    icon: const Icon(Icons.photo_library_outlined, color: Colors.white),
    onPressed: onPickGallery,
  ),
)
```

### 4. Headless Decoding & Barcode Generation (`XueHuaBarcodeScanner`)

```dart
// 1. Generate a Barcode PNG (Uint8List)
final Uint8List pngBytes = await XueHuaBarcodeScanner.encodeBarcode(
  'https://github.com/Matkurban/xue_hua_barcode_scanner',
  width: 512,
  height: 512,
  margin: 2,
  eccLevel: BarcodeEccLevel.high,
);

// 2. Decode from compressed PNG/JPEG bytes or file path
final List<BarcodeResult> fromMemory =
    await XueHuaBarcodeScanner.decodeImageMemory(pngBytes);
final List<BarcodeResult> fromFile =
    await XueHuaBarcodeScanner.decodeImageFile('/path/to/barcode.png');

// 3. Zero-copy YUV420 Y-plane or RGBA8888 decoding with rowStride alignment
final List<BarcodeResult> fromPlanes =
    await XueHuaBarcodeScanner.decodeImageBytes(
  yPlaneBytes,
  width: frameWidth,
  height: frameHeight,
  rowStride: yPlaneBytesPerRow,
  format: PixelFormat.lum,
  tryHarder: true,
  tryRotate: true,
  tryInvert: true,
);
```
