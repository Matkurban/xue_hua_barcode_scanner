[English](README.md) | [简体中文](README_ZH.md)

# xue_hua_barcode_scanner

一款支持 **6 端全平台（Android, iOS, macOS, Windows, Linux, Web）** 的生产级 Flutter 条形码与二维码（Barcode & QR Code）识别、生成及实时相机扫描插件。底层核心统一采用 **`zxing-cpp`**（C++20 FFI）与 **`zxing-wasm`**（`dart:js_interop`）。

- **版本号 (Version)**：`1.0.0`
- **作者 (Author)**：Matkurban <3496354336@qq.com>
- **仓库地址 (Repository)**：[https://github.com/Matkurban/xue_hua_barcode_scanner](https://github.com/Matkurban/xue_hua_barcode_scanner)
- **架构与实现方案**：[架构设计与实现方案 (IMPLEMENTATION_PLAN_ZH.md)](IMPLEMENTATION_PLAN_ZH.md)

## 安装方式 (pub.dev)

通过命令行从 `pub.dev` 安装：

```bash
flutter pub add xue_hua_barcode_scanner
```

或直接在项目的 `pubspec.yaml` 中添加依赖：

```yaml
dependencies:
  xue_hua_barcode_scanner: ^1.0.0
```

## 6 端平台支持矩阵

| 平台 | 底层解码架构 | 相机视频流与取景 | 手电筒 / 闪光灯控制 | 前后摄像头切换 | 本地相册图片识别 |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Android** | `dart:ffi` + `zxing-cpp` (CMake C++20) | YUV420 `yPlane` (`rowStride` 对齐) | 支持硬件开启/关闭与状态监听 | 支持前/后置无缝切换 | 支持 |
| **iOS** | `dart:ffi` + `zxing-cpp` (Podspec C++20) | CoreVideo `BGRA8888` (`rowStride` 对齐) | 支持硬件开启/关闭与状态监听 | 支持前/后置无缝切换 | 支持 |
| **macOS** | `dart:ffi` + `zxing-cpp` (Podspec C++20) | AVFoundation / 外接 USB 摄像头 | 无闪光灯硬件时优雅降级 (`unavailable`) | 支持内置/外接摄像头切换 | 支持 |
| **Windows** | `dart:ffi` + `zxing-cpp` (CMake C++20) | MediaFoundation / UVC 摄像头 | 无闪光灯硬件时优雅降级 (`unavailable`) | 支持多 USB 摄像头切换 | 支持 |
| **Linux** | `dart:ffi` + `zxing-cpp` (CMake C++20) | V4L2 / PipeWire | 无闪光灯硬件时优雅降级 (`unavailable`) | 支持多 USB 摄像头切换 | 支持 |
| **Web** | `dart:js_interop` + `zxing-wasm` / `BarcodeDetector` | `getUserMedia` + `HtmlElementView` | 支持移动端浏览器 `applyConstraints({torch})` | `facingMode: user / environment` | 支持 `<input type="file">` 选图 |

## 核心架构特性

1. **统一的 `zxing-cpp` 解码与生成内核**：
   - **5 个原生端（Android / iOS / macOS / Windows / Linux）**：通过 CMake `FetchContent` 及 CocoaPods 编译 `zxing-cpp`（`v3.1.1`，开启 C++20），经由精简的 `extern "C"` 桥接层（`src/zxing_ffi_bridge.h`）暴露符号，并在 Dart 层通过 `Isolate.run` 异步调用与节流，在 `finally` 块中显式调用 `free_barcode_results` 与 `free_encoded_barcode_image`，严防 FFI 内存泄漏。
   - **Web 端**：使用条件导入（Conditional Imports）彻底隔离 `dart:ffi`，基于现代 `dart:js_interop` 桥接 `zxing-wasm` 与浏览器原生 `BarcodeDetector`，对外提供 100% 一致的 Dart API。
2. **零拷贝单通道 Y 平面与 `rowStride` 字节对齐处理**：
   - `decodeImageBytes` 原生支持直接传入 Android YUV420/NV21 的 `PixelFormat.lum`（Y 平面）或 iOS/macOS 的 `PixelFormat.bgra8888` / `PixelFormat.rgba8888`，自动处理硬件 `rowStride` 行对齐步长，彻底消除因图像行填充导致的斜纹与识别失败。
3. **高颜值开箱即用且 100% 可定制的扫码组件 (`XueHuaBarcodeScannerPage` & `XueHuaScannerView`)**：
   - 默认内置：全屏自适应相机取景、中央半透明镂空遮罩与带高亮边角的方形扫描框、带渐变光晕的绿色上下循环扫描线动画、顶部返回按钮 + **“将二维码放入框内”** 提示语 + 摄像头翻转按钮、底部左右对称分布的 **“手电筒”** 与 **“相册”** 按钮，以及识别成功时的 `cornerPoints` 绿色锚点高亮反馈。
   - 所有组件均支持通过 `overlayBuilder`、`scanLineBuilder`、`topBarBuilder`、`hintTextBuilder`、`bottomBarBuilder`、`torchButtonBuilder`、`galleryButtonBuilder` 完全自定义替换。

## 各端权限与构建配置指南

### 1. Android (`android/app/src/main/AndroidManifest.xml`)
```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-feature android:name="android.hardware.camera" android:required="false" />
<uses-feature android:name="android.hardware.camera.autofocus" android:required="false" />
```

### 2. iOS (`ios/Runner/Info.plist`)
```xml
<key>NSCameraUsageDescription</key>
<string>需要使用相机以扫描条形码和二维码。</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>需要访问相册以从本地图片中识别条形码和二维码。</string>
```

### 3. macOS (`macos/Runner/Info.plist` & Entitlements)
在 `macos/Runner/Info.plist` 中添加 `NSCameraUsageDescription`，并在 `macos/Runner/DebugProfile.entitlements` 和 `macos/Runner/Release.entitlements` 中开启相机权限：
```xml
<key>com.apple.security.device.camera</key>
<true/>
```

### 4. Windows 与 Linux
- **Windows**：需安装 Visual Studio 2022 并勾选“使用 C++ 的桌面开发”（支持 MSVC C++20 与 CMake 3.16+）。
- **Linux**：需安装 `clang` 或 `g++`（支持 C++20）、`cmake`、`ninja-build`、`pkg-config`。

### 5. Web (`web/index.html`)
Web 端调用 `navigator.mediaDevices.getUserMedia` 及移动端手电筒 `MediaStreamTrack.applyConstraints` 需运行在安全上下文（`https://` 或 `http://localhost`）。建议在 `web/index.html` 中引入 `zxing-wasm` 以在所有浏览器中获得完整解码支持：
```html
<script src="https://cdn.jsdelivr.net/npm/zxing-wasm@3.1.1/dist/iife/full/index.js"></script>
```

## 快速上手

### 1. 打开标准默认条码/二维码扫描页
```dart
import 'package:flutter/material.dart';
import 'package:xue_hua_barcode_scanner/xue_hua_barcode_scanner.dart';

Future<void> startScan(BuildContext context) async {
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
    debugPrint('识别文本: ${first.text}, 四个角点坐标: ${first.cornerPoints}');
  }
}
```

### 2. 使用自定义 Builder 替换扫描页面任意组件
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
