[English](IMPLEMENTATION_PLAN.md) | [简体中文](IMPLEMENTATION_PLAN_ZH.md)

# 架构设计与实现方案 — `xue_hua_barcode_scanner` (v1.0.0)

- **插件名称 (Package Name)**：`xue_hua_barcode_scanner`
- **版本号 (Version)**：`1.0.0`
- **作者 (Author)**：Matkurban <3496354336@qq.com>
- **仓库地址 (Repository)**：[https://github.com/Matkurban/xue_hua_barcode_scanner](https://github.com/Matkurban/xue_hua_barcode_scanner)
- **返回中文说明文档**：[中文 README (README_ZH.md)](README_ZH.md)

## 1. 整体架构设计

`xue_hua_barcode_scanner` 基于 **`zxing-cpp`** 构建了支持 **6 端全平台（Android, iOS, macOS, Windows, Linux, Web）** 的条形码/二维码识别、生成与实时相机扫描架构：

1. **5 个原生端（Android, iOS, macOS, Windows, Linux）**：
   - 将 `zxing-cpp`（`v3.1.1`，C++20）编译为原生动态库，通过精简的 `extern "C"` 桥接层（`src/zxing_ffi_bridge.h` / `src/zxing_ffi_bridge.cpp`）暴露符号。
   - 在 Dart 层使用 `dart:ffi` 结合 `Isolate.run` 后台线程执行 `zxing_decode_image_bytes` 与 `zxing_encode_barcode`，并在 `finally` 块中调用 `free_barcode_results` 与 `free_encoded_barcode_image` 释放原生堆内存，避免 UI 卡顿与内存泄漏。
2. **Web 端**：
   - 通过条件导出（`lib/src/core/scanner_engine_selector.dart`）彻底隔离 `dart:ffi`。
   - 基于现代 `dart:js_interop` 与 `dart:ui_web`（`lib/src/web/scanner_web.dart`）桥接 `zxing-wasm` 及浏览器原生 `BarcodeDetector` API，对外提供 100% 一致的 Dart 接口（`XueHuaBarcodeScanner`、`XueHuaScannerController`、`XueHuaBarcodeScannerPage`、`XueHuaScannerView`）。

## 2. 模块划分与 `barcode` 统一命名规范

所有公开及内部文件名、类名与 C 导出符号均统一采用 `barcode` 命名规范：

| 层级 | 文件路径 | 核心类 / 导出符号 |
| :--- | :--- | :--- |
| **公开导出入口** | `lib/xue_hua_barcode_scanner.dart` | 统一导出模型、控制器、平台引擎接口与 UI 扫码组件 |
| **数据模型层** | `lib/src/models/barcode_models.dart` | `BarcodeResult`、`BarcodeFormat`、`BarcodeEccLevel`、`PixelFormat`、`CameraFacing`、`TorchState`、`ScannerState`、`CameraFramePacket` |
| **C/C++20 桥接层** | `src/zxing_ffi_bridge.h`, `src/zxing_ffi_bridge.cpp` | `CBarcodePoint`、`CBarcodeResult`、`CBarcodeResultList`、`CEncodedBarcodeImage`、`zxing_decode_image_bytes`、`free_barcode_results`、`zxing_encode_barcode`、`free_encoded_barcode_image` |
| **FFI 异步解码引擎** | `lib/src/ffi/zxing_ffi_bindings.dart`, `lib/src/ffi/scanner_ffi.dart` | `ZxingFfiBindings`、`XueHuaScannerFfiEngine`、`normalizeRowStrideBuffer` |
| **Web Interop 引擎** | `lib/src/web/scanner_web.dart` | `XueHuaBarcodeScannerWeb`（`getUserMedia`、`applyConstraints({torch})`、`ZXingWasm`、`BarcodeDetector`） |
| **控制器与静态 API** | `lib/src/controller/scanner_controller.dart` | `XueHuaBarcodeScanner`、`XueHuaScannerController` |
| **可定制 UI 组件层** | `lib/src/ui/scanner_overlay.dart`, `lib/src/ui/barcode_scanner_page.dart` | `XueHuaBarcodeScannerPage`、`XueHuaScannerView`、`XueHuaScannerOverlay`、`XueHuaScanLineAnimation`、`XueHuaCornerAnchorHighlight` |

## 3. 6 端编译配置与相机流适配细节

- **CMake 构建（Android, Windows, Linux）**：在 `CMakeLists.txt` 与 `src/CMakeLists.txt` 中统一设置 `VERSION 1.0.0`、`CMAKE_CXX_STANDARD 20`，通过 `FetchContent` 自动拉取 `zxing-cpp` `v3.1.1`（关闭 `ZXING_EXAMPLES` 与 `ZXING_UNIT_TESTS`，并配置 Android 15+ 的 16KB 页大小对齐）。
- **CocoaPods 构建（iOS, macOS）**：在 `ios/xue_hua_barcode_scanner.podspec` 与 `macos/xue_hua_barcode_scanner.podspec` 中统一设置 `s.version = '1.0.0'`、`CLANG_CXX_LANGUAGE_STANDARD = 'c++20'`，并通过 `-Wl,-exported_symbol` 防止 Xcode Release 归档剥离 FFI 符号。
- **`rowStride` 字节对齐与传感器角度映射**：`normalizeRowStrideBuffer` 自动处理 Android `YUV_420_888`（`PixelFormat.lum`）与 iOS/macOS `BGRA8888` 的行字节对齐步长；`BarcodeResult.mapCornersToViewport` 自动处理相机传感器 `0°/90°/180°/270°` 旋转角度及前置摄像头镜像坐标映射。
- **桌面端与 Web 端优雅降级**：桌面端无闪光灯硬件时自动将手电筒状态置为 `TorchState.unavailable`；Web 端支持通过 `MediaStreamTrack.applyConstraints({advanced: [{torch: true}]})` 控制移动端浏览器手电筒。
