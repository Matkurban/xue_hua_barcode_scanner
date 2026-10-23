[English](README.md) | [简体中文](README_ZH.md)

# xue_hua_barcode_scanner

一款支持 **6 端全平台（Android, iOS, macOS, Windows, Linux, Web）** 的生产级 Flutter 条形码与二维码（Barcode & QR Code）识别、生成及实时相机扫描插件。底层核心统一采用 **`zxing-cpp`**（`v3.1.1`，C++20 FFI）与 **`zxing-wasm`**（`dart:js_interop`）。

- **版本号 (Version)**：`1.0.0`
- **环境要求 (Environment)**：Dart `^3.13.0` | Flutter `>=3.47.0`
- **作者 (Author)**：Matkurban <3496354336@qq.com>
- **仓库地址 (Repository)**：[https://github.com/Matkurban/xue_hua_barcode_scanner](https://github.com/Matkurban/xue_hua_barcode_scanner)

## 6 端平台支持矩阵

| 平台 | 底层解码架构 | 相机视频流与取景 | 手电筒 / 闪光灯控制 | 前后摄像头切换 | 本地相册图片识别 |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Android** | `dart:ffi` + `zxing-cpp 3.1.1` (CMake C++20) | Camera2 `SurfaceTextureEntry` + `YUV_420_888` (`yPlane` `rowStride` 对齐) | 支持硬件开启/关闭 (`FLASH_MODE_TORCH`) | 支持前/后置/外接切换 | 支持 (`ACTION_GET_CONTENT`) |
| **iOS** | `dart:ffi` + `zxing-cpp 3.1.1` (SwiftPM / Podspec C++20) | `AVCaptureSession` + `FlutterTexture` (`BGRA8888` 对齐) | 支持硬件开启/关闭 (`torchMode`) | 支持前/后置无缝切换 | 支持 (`UIImagePickerController`) |
| **macOS** | `dart:ffi` + `zxing-cpp 3.1.1` (SwiftPM / Podspec C++20) | `AVCaptureSession` + `FlutterTexture` (`BGRA8888`) | 无闪光灯硬件时优雅降级 (`unavailable`) | 支持内置/外接 USB 摄像头切换 | 支持 (`NSOpenPanel`) |
| **Windows** | `dart:ffi` + `zxing-cpp 3.1.1` (CMake C++20) | MediaFoundation `IMFSourceReader` + `PixelBufferTexture` | 无闪光灯硬件时优雅降级 (`unavailable`) | 支持多 USB 摄像头切换 | 支持 (`GetOpenFileNameW`) |
| **Linux** | `dart:ffi` + `zxing-cpp 3.1.1` (CMake C++20) | V4L2 / PipeWire | 无闪光灯硬件时优雅降级 (`unavailable`) | 支持多 USB 摄像头切换 | 支持 (`GtkFileChooserNative`) |
| **Web** | `dart:js_interop` + `zxing-wasm` / `BarcodeDetector` | `getUserMedia` + `HtmlElementView` | 支持移动端浏览器 `applyConstraints({torch})` | `facingMode: user / environment` | 支持 `<input type="file">` 选图 |

## 核心架构特性

1. **统一的 `zxing-cpp 3.1.1` 解码与生成内核**：
   - **5 个原生端（Android / iOS / macOS / Windows / Linux）**：通过 CMake `FetchContent`、Swift Package Manager (`Package.swift`) 及 CocoaPods 编译 `zxing-cpp`（`v3.1.1`，开启 C++20），经由精简的 `extern "C"` 桥接层（`src/zxing_ffi_bridge.h`）暴露符号，并在 Dart 层通过 `Isolate.run` 异步调用与节流，在 `finally` 块中显式调用 `free_barcode_results` 与 `free_encoded_barcode_image`，严防 FFI 内存泄漏。
   - **Web 端**：使用条件导入（Conditional Imports）彻底隔离 `dart:ffi`，基于现代 `dart:js_interop` 桥接 `zxing-wasm` 与浏览器原生 `BarcodeDetector`，对外提供 100% 一致的 Dart API。
2. **零拷贝单通道 Y 平面与 `rowStride` 字节对齐处理**：
   - `decodeImageBytes` 原生支持直接传入 Android YUV420/NV21 的 `PixelFormat.lum`（Y 平面）或 iOS/macOS 的 `PixelFormat.bgra8888` / `PixelFormat.rgba8888`，自动处理硬件 `rowStride` 行对齐步长，彻底消除因图像行填充导致的斜纹与识别失败。
3. **高颜值开箱即用且 100% 可定制的扫码组件 (`XueHuaBarcodeScannerPage` & `XueHuaScannerView`)**：
   - 默认内置：全屏自适应相机取景 (`Texture` / `HtmlElementView`)、中央半透明镂空遮罩与带高亮边角的方形扫描框、带渐变光晕的绿色上下循环扫描线动画、顶部返回按钮 + **“将二维码放入框内”** 提示语 + 摄像头翻转按钮、底部左右对称分布的 **“手电筒”** 与 **“相册”** 按钮，以及识别成功时的 `cornerPoints` 绿色锚点高亮反馈。
   - 所有组件均支持通过 `overlayBuilder`、`scanLineBuilder`、`topBarBuilder`、`hintTextBuilder`、`bottomBarBuilder`、`torchButtonBuilder`、`galleryButtonBuilder` 完全自定义替换。

---

## 完整集成教程与全平台权限配置指南

### 第一步：环境要求与安装依赖

请确保开发环境满足 **Flutter `>=3.47.0`** 与 **Dart `^3.13.0`**，通过命令行添加依赖：

```bash
flutter pub add xue_hua_barcode_scanner
```

或在项目的 `pubspec.yaml` 中配置：

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

### 第二步：各平台权限与原生构建配置（必读）

#### 1. Android 端集成与权限配置 (`android/app/src/main/AndroidManifest.xml`)

- **所需权限明细**：
  - `android.permission.CAMERA`：**必须配置**。用于开启实时相机预览、视频帧条码识别及闪光灯控制。插件内部已集成动态权限请求逻辑，调用 `startCamera` 或打开 `XueHuaBarcodeScannerPage` 时会自动弹出系统相机授权框。
  - `android.hardware.camera` 与 `android.hardware.camera.autofocus`：建议声明并设置 `android:required="false"`，以便无后置摄像头的设备也能安装应用并使用相册/静态图片解码功能。
  - **相册选图权限说明**：插件通过系统 `Intent.ACTION_GET_CONTENT` (`image/*`) 选择图片，**无需**申请 `READ_EXTERNAL_STORAGE` 或 `READ_MEDIA_IMAGES` 存储权限。

在 `android/app/src/main/AndroidManifest.xml` 的 `<manifest>` 根节点下添加：

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <!-- 实时相机扫码与手电筒控制权限（必须） -->
    <uses-permission android:name="android.permission.CAMERA" />
    <uses-feature android:name="android.hardware.camera" android:required="false" />
    <uses-feature android:name="android.hardware.camera.autofocus" android:required="false" />

    <application ...>
        ...
    </application>
</manifest>
```

- **编译要求**：`minSdk >= 24`，插件已内置 CMake `FetchContent` 自动拉取并编译 `zxing-cpp v3.1.1` (C++20)，且默认开启 Android 15+ 的 16KB 页大小对齐。

#### 2. iOS 端集成与权限配置 (`ios/Runner/Info.plist`)

- **所需权限明细**（若未在 `Info.plist` 中声明，iOS 系统会在调用相机或相册时直接崩溃退出）：
  - `NSCameraUsageDescription`：**必须配置**。用于 `AVCaptureSession` 实时相机预览与扫码识别。
  - `NSPhotoLibraryUsageDescription`：**必须配置**。用于从系统相册选择条码/二维码图片 (`analyzeImageFromGallery`)。

在 `ios/Runner/Info.plist` 的 `<dict>` 中添加：

```xml
<key>NSCameraUsageDescription</key>
<string>需要使用相机以实时扫描条形码和二维码。</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>需要访问相册以从本地图片中识别条形码和二维码。</string>
```

- **构建管理支持**：同时支持 **Swift Package Manager (SwiftPM)**（`ios/xue_hua_barcode_scanner/Package.swift`，Flutter 3.47+ 默认启用）与 **CocoaPods**（`ios/xue_hua_barcode_scanner.podspec`），最低系统版本要求为 **iOS `13.0`**。

#### 3. macOS 端集成与权限配置 (`Info.plist` + Sandbox Entitlements)

macOS 默认开启应用沙盒（App Sandbox），**必须同时配置 `Info.plist` 权限描述与 `.entitlements` 沙盒权限**，否则无法看到摄像头画面：

1. **在 `macos/Runner/Info.plist` 的 `<dict>` 中添加权限描述**：
```xml
<key>NSCameraUsageDescription</key>
<string>需要使用摄像头以实时扫描条形码和二维码。</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>需要访问本地图片以识别条形码和二维码。</string>
```

2. **在 `macos/Runner/DebugProfile.entitlements` 和 `macos/Runner/Release.entitlements` 两个文件中同时开启硬件相机与文件选择权限**：
   - `com.apple.security.device.camera`：**必须开启 (`<true/>`)**。若缺失该项，macOS 沙盒会直接拦截摄像头硬件访问，不会弹出权限框也无法获取画面。
   - `com.apple.security.files.user-selected.read-only`：允许通过系统 `NSOpenPanel` 选择本地图片进行条码识别。

```xml
<key>com.apple.security.device.camera</key>
<true/>
<key>com.apple.security.files.user-selected.read-only</key>
<true/>
```

- **构建管理支持**：同时支持 **Swift Package Manager (SwiftPM)**（`macos/xue_hua_barcode_scanner/Package.swift`）与 **CocoaPods**（`macos/xue_hua_barcode_scanner.podspec`），最低系统版本要求为 **macOS `10.15`**。

#### 4. Windows 端集成与权限配置

- **系统权限要求**：无需修改工程配置文件，仅需确保 Windows 系统设置中已开启摄像头访问权限（`设置 -> 隐私和安全性 -> 摄像头 -> 允许桌面应用访问你的摄像头`）。
- **构建环境要求**：需安装 Visual Studio 2022 并勾选 **“使用 C++ 的桌面开发”**（支持 MSVC C++20 与 CMake `3.16+`）。插件底层通过 Windows MediaFoundation 采集摄像头画面，并通过 Win32 文件对话框选择本地条码图片。

#### 5. Linux 端集成与权限配置

- **系统权限要求**：确保当前运行用户拥有读取 `/dev/video*` 摄像头设备节点的权限（通常位于 `video` 用户组：`sudo usermod -aG video $USER`）。
- **构建环境要求**：需安装 `clang` 或 `g++`（支持 C++20）、`cmake`（`3.16+`）、`ninja-build`、`pkg-config` 及 `libgtk-3-dev`。

#### 6. Web 端集成与权限配置 (`web/index.html`)

- **浏览器权限与安全上下文要求**：
  - Web 端调用 `navigator.mediaDevices.getUserMedia`（开启摄像头视频流）及 `MediaStreamTrack.applyConstraints({advanced: [{torch: true}]})`（移动端浏览器手电筒）**必须运行在安全上下文 (`https://` 或 `http://localhost`)**，进入扫码页时浏览器会自动弹出摄像头授权提示。
- **在 `web/index.html` 中引入 `zxing-wasm`**：
  建议在 `web/index.html` 的 `<head>` 中引入 `zxing-wasm`（版本 `3.1.1`），以便在所有桌面与移动端浏览器中获得完整的 WebAssembly 解码能力：

```html
<script src="https://cdn.jsdelivr.net/npm/zxing-wasm@3.1.1/dist/iife/full/index.js"></script>
```

---

## 快速上手

### 1. 打开标准默认条码/二维码扫描页

```dart
import 'package:material_ui/material_ui.dart';
import 'package:xue_hua_barcode_scanner/xue_hua_barcode_scanner.dart';

Future<void> startScan(BuildContext context) async {
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
    debugPrint('识别文本: ${first.text}, 四个角点坐标: ${first.cornerPoints}');
  }
}
```

### 2. 使用自定义 Builder 替换扫描页面任意组件

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

### 3. 直接调用静态图片解码与条码生成 API

```dart
// 1. 生成条码 PNG 字节流
final Uint8List pngBytes = await XueHuaBarcodeScanner.encodeBarcode(
  'https://github.com/Matkurban/xue_hua_barcode_scanner',
  width: 512,
  height: 512,
  margin: 2,
  eccLevel: BarcodeEccLevel.high,
);

// 2. 从压缩图片字节流或本地文件路径解码条码
final List<BarcodeResult> fromMemory =
    await XueHuaBarcodeScanner.decodeImageMemory(pngBytes);
final List<BarcodeResult> fromFile =
    await XueHuaBarcodeScanner.decodeImageFile('/path/to/barcode.png');

// 3. 从相机 Y 平面或 RGBA8888 原始字节流解码（支持 rowStride 对齐）
final List<BarcodeResult> fromPixels =
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

## `XueHuaScannerController` 核心 API 列表

| 方法 / 属性 | 说明 |
| :--- | :--- |
| `ValueListenable<ScannerState> stateListenable` | 监听相机初始化状态、手电筒状态 (`torchState`)、当前镜头方向 (`cameraFacing`) 及最新识别结果 (`latestResults`)。 |
| `Future<void> start()` / `stop()` | 启动或停止相机取景流。 |
| `Future<void> pause()` / `resume()` | 暂停或恢复实时帧解码与扫描线动画。 |
| `Future<bool> toggleTorch()` | 开启/关闭手电筒；在无闪光灯的桌面端自动安全降级并返回 `false`。 |
| `Future<void> switchCamera()` | 切换前/后置摄像头（或桌面端多个外接 USB 摄像头）。 |
| `Future<List<BarcodeResult>> analyzeImageFromGallery()` | 从本地相册选图并调用 `zxing-cpp` 识别其中的条码/二维码。 |

## 开源协议

详见 [LICENSE](LICENSE) 文件。
