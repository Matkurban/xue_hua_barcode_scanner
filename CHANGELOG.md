## Unreleased

* Enumerate camera input sources and select one by id on Android, iOS, macOS, Windows, Linux, and Web. Opening the scanner still starts the platform default camera.
* When more than one input source is available, the default scanner page opens a `chat_context_menu` menu from the top-bar camera button. A single source hides that control, and the menu is not shown on entry.
* Add `chat_context_menu: ^4.2.0`. The package version is intentionally unchanged in this change.

## 1.0.2

* Shorten the package description in `pubspec.yaml` so it stays between 60 and 180 characters and pub.dev can score a valid pubspec.

## 1.0.1

* Fix Windows MediaFoundation camera media type setup: use `IMFMediaType::SetGUID(MF_MT_MAJOR_TYPE/SUBTYPE)` instead of non-existent `SetMajorType`/`SetSubtype`.
* Fix Windows Flutter install failure when embedding `zxing-cpp` via FetchContent: declare dependency with `EXCLUDE_FROM_ALL` and provide a no-op install stub so generator-expression `CMAKE_INSTALL_PREFIX` no longer breaks the build.

## 1.0.0

* Initial stable `1.0.0` release of `xue_hua_barcode_scanner` by Matkurban <3496354336@qq.com>.
* Unified `zxing-cpp` (C++20) FFI & WebAssembly (`dart:js_interop`) barcode recognition and generation engine across Android, iOS, macOS, Windows, Linux, and Web.
* High-performance `Isolate` worker decoding with `rowStride` alignment support for YUV420 (`yPlane`), `RGBA8888`, and `BGRA8888` streams.
* Built-in `XueHuaBarcodeScannerPage` and `XueHuaScannerView` with animated green laser scan line, corner borders, real-time corner-point anchor highlights, torch control, front/back camera switching, and gallery image recognition.
* 100% customizable UI via `overlayBuilder`, `scanLineBuilder`, `topBarBuilder`, `hintTextBuilder`, `bottomBarBuilder`, `torchButtonBuilder`, and `galleryButtonBuilder`.
* Included Dart Package Skill (`skills/xue-hua-barcode-scanner/SKILL.md`).
