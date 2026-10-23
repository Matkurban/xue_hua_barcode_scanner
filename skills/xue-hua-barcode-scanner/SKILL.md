---
name: xue-hua-barcode-scanner
description: Use when the user is working with xue_hua_barcode_scanner APIs to scan barcodes or QR codes in real time, customize XueHuaBarcodeScannerPage or XueHuaScannerView UI builders, control camera torch/facing via XueHuaScannerController, or decode/encode barcodes using zxing-cpp FFI and WebAssembly across Android, iOS, macOS, Windows, Linux, and Web.
---
# xue-hua-barcode-scanner

Provide idiomatic integration patterns, UI customization builders, controller lifecycle management, and 6-platform configuration rules for the `xue_hua_barcode_scanner` Flutter plugin (`https://github.com/Matkurban/xue_hua_barcode_scanner`).

## When to Use

- Opening a ready-to-use full-screen barcode scanner page (`XueHuaBarcodeScannerPage`) or embedding a camera scanner view (`XueHuaScannerView`)
- Customizing any scanner UI element (`overlayBuilder`, `scanLineBuilder`, `topBarBuilder`, `hintTextBuilder`, `bottomBarBuilder`, `torchButtonBuilder`, `galleryButtonBuilder`)
- Programmatically controlling the flashlight/torch (`toggleTorch`), switching front/back/external cameras (`switchCamera`), pausing/resuming streams (`pause`, `resume`), or picking an image from the photo gallery (`analyzeImageFromGallery`) via `XueHuaScannerController`
- Decoding barcodes / QR codes directly from raw camera planes (`decodeImageBytes` with `PixelFormat.lum` / `rgba8888` / `bgra8888` and `rowStride`), local image files (`decodeImageFile`), or compressed PNG/JPEG bytes (`decodeImageMemory`)
- Generating barcode PNG images (`encodeBarcode`) with configurable dimensions, margin, and `BarcodeEccLevel`

## Steps

### 1. Launch Default `XueHuaBarcodeScannerPage`

```dart
import 'package:flutter/material.dart';
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

1. Instantiate `XueHuaScannerController` and pass it to `XueHuaBarcodeScannerPage` or `XueHuaScannerView`.
2. Listen to `controller` (`ValueListenable<ScannerState>`) via `ValueListenableBuilder<ScannerState>` to inspect `state.isTorchOn`, `state.hasTorch`, `state.cameraFacing`, and `state.latestResults`.
3. Call `controller.toggleTorch()`, `controller.switchCamera()`, `controller.pause()`, `controller.resume()`, or `controller.analyzeImageFromGallery()`.
4. Always dispose externally created controllers in `State.dispose()`.

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

## Platform Setup & Troubleshooting Gotchas

- **Android (`AndroidManifest.xml`)**: Declare `<uses-permission android:name="android.permission.CAMERA" />`. When passing Android Camera2 / CameraX `YUV_420_888` plane 0 (`yPlane`), always pass `plane.bytesPerRow` as `rowStride` so padded rows on Qualcomm/MediaTek ISPs do not skew the image.
- **iOS & macOS (`Info.plist` & Podspec)**: Add `NSCameraUsageDescription` and `NSPhotoLibraryUsageDescription` to `Info.plist`. On macOS, also enable `com.apple.security.device.camera` in `DebugProfile.entitlements` and `Release.entitlements`. The plugin's `.podspec` automatically sets `CLANG_CXX_LANGUAGE_STANDARD = 'c++20'` and `-Wl,-exported_symbol` flags so Xcode Release archives do not strip FFI symbols.
- **Desktop (macOS / Windows / Linux)**: Desktop webcams typically lack rear LED flash hardware. `ScannerState.hasTorch` automatically evaluates to `false` (`TorchState.unavailable`); set `hideTorchWhenUnavailable: true` on `XueHuaBarcodeScannerPage` if you prefer to hide the torch button on desktop.
- **Web (`index.html`)**: Camera streaming via `navigator.mediaDevices.getUserMedia` and mobile torch constraints (`track.applyConstraints({advanced: [{torch: true}]})`) require a secure context (`https://` or `http://localhost`). For optimal `zxing-wasm` performance in browsers without native `BarcodeDetector`, include `<script src="https://cdn.jsdelivr.net/npm/zxing-wasm@3.1.1/dist/iife/full/index.js"></script>` in `web/index.html`.
