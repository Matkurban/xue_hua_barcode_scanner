## Unreleased

* Send Windows camera frames on the platform thread. Media Foundation `ReadSample` was calling the frames `EventChannel` sink from the capture thread, which Flutter logs as `shell.cc` "channel sent a message from native to Flutter on a non-platform thread". Frames are now queued and delivered from the top-level window procedure. Android (`main` looper), iOS, and macOS (`DispatchQueue.main`) already hop to the platform thread before `success`. Linux does not open this channel.
* Add `flutter_driver` coverage for the example app. Run it on Windows with `flutter drive -d windows --target=test_driver/app.dart` (a webcam is fine). The same suite still passes on Linux with no camera. Gallery file pickers stay out of the driver run because Windows `GetOpenFileName` and the Linux GTK chooser block the platform thread.
* Example row-stride action now decodes a padded Y plane through `decodeImageBytes` and reports failures in the status log.
* Load the Linux/Android zxing library from the unversioned soname or from `lib/` next to the executable. A `VERSION`/`SOVERSION` build previously bundled only `libxue_hua_barcode_scanner.so.1.0.0`, so `dlopen` missed it and image decode silently fell back. Linux and Android builds no longer version that private library. Windows also tries `xue_hua_barcode_scanner.dll` beside the executable when the bare name does not resolve.

## 1.0.5 - 2026-10-24

* Wrap `chat_context_menu` `menuBuilder` content in `Material(type: MaterialType.transparency)`.

## 1.0.4 - 2026-10-24

* Fix the macOS build on deployment targets older than 14.0: `AVCaptureDevice.DeviceType.continuityCamera` is only available on macOS 14.0 or newer, so discover it inside the existing `#available(macOS 14.0, *)` check instead of `#available(macOS 13.0, *)`.

## 1.0.3 - 2026-10-24

* Enumerate camera input sources and select one by id on Android, iOS, macOS, Windows, Linux, and Web. Opening the scanner still starts the platform default camera.
* When more than one input source is available, the default scanner page opens a `chat_context_menu` menu from the top-bar camera button. A single source hides that control, and the menu is not shown on entry.
* Add `chat_context_menu: ^4.2.0`.
* Compile the Windows plugin with MSVC `/utf-8` so UTF-8 fallback camera labels build on code page 936 with `/WX`.

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

