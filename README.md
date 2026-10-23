[English](README.md) | [简体中文](README_ZH.md)

# xue_hua_barcode_scanner

A production-grade, 6-platform (**Android, iOS, macOS, Windows, Linux, Web**) Flutter Barcode & QR Code recognition, generation, and real-time camera scanner plugin powered by **`zxing-cpp`** (`v3.1.1`, C++20 FFI) and **`zxing-wasm`** (`dart:js_interop`).

- **Version**: `1.0.0`
- **Environment**: Dart `^3.13.0` | Flutter `>=3.47.0`
- **Author**: Matkurban <3496354336@qq.com>
- **Repository**: [https://github.com/Matkurban/xue_hua_barcode_scanner](https://github.com/Matkurban/xue_hua_barcode_scanner)

## Platform Support Matrix

| Platform | Engine Architecture | Camera Stream & Preview | Torch / Flashlight | Front / Back Camera Switch | Gallery Image Decode |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Android** | `dart:ffi` + `zxing-cpp 3.1.1` (CMake C++20) | Camera2 `SurfaceTextureEntry` + `YUV_420_888` (`yPlane` `rowStride`) | Supported (`FLASH_MODE_TORCH`) | Supported (Back / Front / External) | Supported (`ACTION_GET_CONTENT`) |
| **iOS** | `dart:ffi` + `zxing-cpp 3.1.1` (SwiftPM / Podspec C++20) | `AVCaptureSession` + `FlutterTexture` (`BGRA8888`) | Supported (`AVCaptureDevice.torchMode`) | Supported (Back / Front) | Supported (`UIImagePickerController`) |
| **macOS** | `dart:ffi` + `zxing-cpp 3.1.1` (SwiftPM / Podspec C++20) | `AVCaptureSession` + `FlutterTexture` (`BGRA8888`) | Graceful fallback (`unavailable`) | Built-in / External USB | Supported (`NSOpenPanel`) |
| **Windows** | `dart:ffi` + `zxing-cpp 3.1.1` (CMake C++20) | MediaFoundation `IMFSourceReader` + `PixelBufferTexture` | Graceful fallback (`unavailable`) | Built-in / External USB | Supported (`GetOpenFileNameW`) |
| **Linux** | `dart:ffi` + `zxing-cpp 3.1.1` (CMake C++20) | V4L2 / PipeWire | Graceful fallback (`unavailable`) | Built-in / External USB | Supported (`GtkFileChooserNative`) |
| **Web** | `dart:js_interop` + `zxing-wasm` / `BarcodeDetector` | `getUserMedia` + `HtmlElementView` | Mobile Web `applyConstraints({torch})` | `facingMode: user / environment` | File input (`image/*`) |

## Key Features

1. **Unified `zxing-cpp 3.1.1` Decoding & Generation Core**:
   - **5 Native Platforms**: Compiles `zxing-cpp` (`v3.1.1`) via CMake `FetchContent`, Swift Package Manager (`Package.swift`), and CocoaPods C++20, bridged through an `extern "C"` wrapper (`src/zxing_ffi_bridge.h`) and executed inside background `Isolate.run` workers with deterministic native heap deallocation (`free_barcode_results`, `free_encoded_barcode_image`).
   - **Web Platform**: Isolates `dart:ffi` via conditional imports and uses modern `dart:js_interop` to bridge `zxing-wasm` and the browser's `BarcodeDetector` API with 100% identical Dart APIs.
2. **Zero-Copy Y-Plane & `rowStride` Alignment**:
   - Directly decodes single-channel grayscale (`PixelFormat.lum` for Android `YUV_420_888` / `NV21` Y-plane), `PixelFormat.rgba8888`, `PixelFormat.bgra8888`, and `PixelFormat.rgb888` while normalizing hardware row alignment padding (`rowStride`) to prevent diagonal image skew.
3. **Out-of-the-Box & 100% Customizable `XueHuaBarcodeScannerPage`**:
   - Full-screen aspect-ratio-preserving camera preview (`Texture` / `HtmlElementView`), semi-transparent rounded-square cutout overlay with 4 glowing corner brackets, smooth looping green laser scan line, top bar with Back button, `"将二维码放入框内"` prompt, and Front/Back camera flip button, bottom symmetric **Torch** and **Gallery** buttons, and real-time green anchor highlights on detected `cornerPoints`.
   - Every visual component can be overridden via `overlayBuilder`, `scanLineBuilder`, `topBarBuilder`, `hintTextBuilder`, `bottomBarBuilder`, `torchButtonBuilder`, and `galleryButtonBuilder`.

---

## Step-by-Step Integration Tutorial & Required Permissions

### Step 1: Add Dependency

 Ensure your environment meets the minimum requirements (**Flutter `>=3.47.0`**, **Dart `^3.13.0`**), then add the plugin:

```bash
flutter pub add xue_hua_barcode_scanner
```

Or add it to your `pubspec.yaml`:

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

### Step 2: Configure Platform Permissions & Native Build Settings

#### 1. Android (`android/app/src/main/AndroidManifest.xml`)

- **Required Permissions**:
  - `android.permission.CAMERA`: **Required** for real-time camera preview, barcode scanning, and flashlight control. The plugin automatically triggers the system runtime permission dialog when `start()` / `XueHuaBarcodeScannerPage` is opened.
  - `android.hardware.camera` & `android.hardware.camera.autofocus`: Declared with `android:required="false"` so devices without rear cameras or autofocus can still install the app and use gallery/static image decoding.
  - **Gallery Image Picking**: Uses the system document picker (`Intent.ACTION_GET_CONTENT` with `image/*`), which **does not** require `READ_EXTERNAL_STORAGE` or `READ_MEDIA_IMAGES` permissions.

Add the following inside `android/app/src/main/AndroidManifest.xml` (above `<application>`):

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <!-- Required for real-time camera scanning and flashlight -->
    <uses-permission android:name="android.permission.CAMERA" />
    <uses-feature android:name="android.hardware.camera" android:required="false" />
    <uses-feature android:name="android.hardware.camera.autofocus" android:required="false" />

    <application ...>
        ...
    </application>
</manifest>
```

- **SDK & NDK Requirements**: `minSdk >= 24`, CMake `3.16+` with C++20 support (configured automatically by the plugin's `android/build.gradle`, including Android 15+ 16KB page size alignment).

#### 2. iOS (`ios/Runner/Info.plist`)

- **Required Privacy Descriptions** (iOS will terminate the app if these keys are missing when accessing the camera or photo library):
  - `NSCameraUsageDescription`: **Required** for real-time camera barcode scanning (`AVCaptureSession`).
  - `NSPhotoLibraryUsageDescription`: **Required** for selecting barcode images from the system photo library (`analyzeImageFromGallery`).

Add both keys inside `<dict>` in `ios/Runner/Info.plist`:

```xml
<key>NSCameraUsageDescription</key>
<string>Camera access is required to scan barcodes and QR codes in real time.</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>Photo library access is required to recognize barcodes from saved images.</string>
```

- **Build System**: Supports both **Swift Package Manager (SwiftPM)** (`ios/xue_hua_barcode_scanner/Package.swift`) and **CocoaPods** (`ios/xue_hua_barcode_scanner.podspec`), minimum deployment target **iOS `13.0`**.

#### 3. macOS (`macos/Runner/Info.plist` & Entitlements)

macOS apps run inside Apple's App Sandbox by default and require **both** `Info.plist` usage descriptions **and** explicit Sandbox Entitlements:

1. **Add Privacy Keys in `macos/Runner/Info.plist`**:
```xml
<key>NSCameraUsageDescription</key>
<string>Camera access is required to scan barcodes and QR codes in real time.</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>File access is required to recognize barcodes from local images.</string>
```

2. **Enable Camera & File Picker Entitlements in BOTH `macos/Runner/DebugProfile.entitlements` AND `macos/Runner/Release.entitlements`**:
   - `com.apple.security.device.camera`: **Mandatory**. Without this entitlement, macOS blocks camera access inside the sandbox even if `NSCameraUsageDescription` is set.
   - `com.apple.security.files.user-selected.read-only`: Allows `NSOpenPanel` to read user-selected barcode images from disk.

```xml
<key>com.apple.security.device.camera</key>
<true/>
<key>com.apple.security.files.user-selected.read-only</key>
<true/>
```

- **Build System**: Supports both **Swift Package Manager (SwiftPM)** (`macos/xue_hua_barcode_scanner/Package.swift`) and **CocoaPods** (`macos/xue_hua_barcode_scanner.podspec`), minimum deployment target **macOS `10.15`**.

#### 4. Windows

- **Permissions**: No manifest XML changes are required in the project. Ensure camera access is enabled in Windows System Settings (`Settings -> Privacy & security -> Camera -> Let desktop apps access your camera`).
- **Build Toolchain**: Requires Visual Studio 2022 with the **"Desktop development with C++"** workload (MSVC C++20 compiler and CMake `3.16+`). Camera capture is powered natively by Windows MediaFoundation (`mf.lib`, `mfplat.lib`, `mfreadwrite.lib`).

#### 5. Linux

- **Permissions**: The current Linux user must have read permission for V4L2 camera nodes (`/dev/video*`, typically granted via the `video` user group: `sudo usermod -aG video $USER`). Local image picking uses `GtkFileChooserNative`.
- **Build Toolchain**: Requires `clang` or `g++` (C++20), `cmake` (`3.16+`), `ninja-build`, `pkg-config`, and `libgtk-3-dev`.

#### 6. Web (`web/index.html`)

- **Browser Permissions & Secure Context**:
  - `navigator.mediaDevices.getUserMedia` (camera stream) and `MediaStreamTrack.applyConstraints({advanced: [{torch: true}]})` (mobile browser flashlight) **only work in a Secure Context** (`https://` or `http://localhost`).
  - The browser automatically prompts the user for camera permission when the scanner starts.
- **Include `zxing-wasm` in `web/index.html`**:
  Add the `zxing-wasm` script inside `<head>` in `web/index.html` for full WebAssembly barcode decoding across all browsers:

```html
<script src="https://cdn.jsdelivr.net/npm/zxing-wasm@3.1.1/dist/iife/full/index.js"></script>
```

---

## Quick Start

### 1. Open the Standard Barcode Scanner Page

```dart
import 'package:material_ui/material_ui.dart';
import 'package:xue_hua_barcode_scanner/xue_hua_barcode_scanner.dart';

Future<void> scanBarcode(BuildContext context) async {
  final List<BarcodeResult>? results = await Navigator.of(context).push(
    MaterialPageRoute<List<BarcodeResult>>(
      builder: (_) => XueHuaBarcodeScannerPage(
        autoPopOnDetect: true,
        texts: const XueHuaScannerTexts(
          hintText: '将二维码放入框内',
          invalidBarcodeText: '二维码不符合要求',
        ),
        validator: (result) => result.text.isNotEmpty,
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
import 'package:material_ui/material_ui.dart';
import 'package:xue_hua_barcode_scanner/xue_hua_barcode_scanner.dart';

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
| `Future<void> switchCamera()` | Switches between rear (`CameraFacing.back`) and front (`CameraFacing.front`) cameras (or external USB cameras on desktop). |
| `Future<List<BarcodeResult>> analyzeImageFromGallery()` | Picks an image from the local gallery/filesystem and decodes barcodes. |

## License

See [LICENSE](LICENSE) for full license terms.
