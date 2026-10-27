# Example driver tests

Classic `flutter_driver` smoke for the example app. The instrumented entry is `test_driver/app.dart` (`enableFlutterDriverExtension`). Everyday `flutter run` still uses `lib/main.dart` and does not install the extension.

The acceptance target is **desktop** (Windows and macOS). Linux stays runnable for machines without a camera.

## Run on macOS

From the `example` directory, with the `macos` device:

```bash
cd example
flutter drive -d macos --target=test_driver/app.dart
```

A built-in or Continuity camera is fine. Desktop flash is unavailable, so the torch control should show the unsupported snackbar (or leave the label unchanged only before camera init finishes; the suite retries). Gallery file pickers stay out of the driver run because `NSOpenPanel` blocks the platform thread.

## Run on Windows

From the `example` directory, with the `windows` device:

```bash
cd example
flutter drive -d windows --target=test_driver/app.dart
```

A webcam is the common case. The scanner tests accept a live preview (no error label). If the camera cannot open, they accept the error placeholder instead of failing. A barcode in the frame may open the result dialog; the suite dismisses it with **继续扫码** and still navigates back.

## Run on Linux

From the `example` directory, with a display (or Xvfb) and the `linux` device:

```bash
cd example
flutter drive -d linux --target=test_driver/app.dart
```

If this machine has no display:

```bash
cd example
xvfb-run -a flutter drive -d linux --target=test_driver/app.dart
```

No `/dev/video*` is required. The preview may say the camera is unavailable; that is a pass.

`flutter drive` looks up `test_driver/app_test.dart` from that target. Flutter 3.47.x is the version this package is developed against.

The existing widget test is separate:

```bash
cd example
flutter test test/input_source_menu_demo_test.dart
```

## Covered

- Home page engine label, generated QR preview, and `decodeImageMemory` round trip.
- Empty payload does not wipe the last success; a new payload is encoded and decoded.
- ECC and module-shape menus, then another decode.
- Padded Y-plane `decodeImageBytes` (`rowStride` greater than the image width).
- Input-source demo: multi-camera menu, single-camera control stays hidden, back navigation.
- Default and custom scanner pages: hint, torch, gallery control, back navigation.
- Camera present (typical Windows): live texture, no crash, torch reports that the desktop device has no flash or the label changes, and the camera menu is used when more than one device is listed.
- Camera missing (typical Linux): the page stays up. The test accepts the error placeholder (`相机不可用` / `NO_CAMERA` / `No V4L2` / `webcam`) or a non-texture preview (`取景`).
- If a live frame opens the scan-result dialog, **继续扫码** is tapped so the rest of the page can still be driven.

## Intentionally skipped

- Tapping **从相册选图解码** or the scanner gallery button. `pickImageFilePath` opens a modal file chooser on the platform thread (`GetOpenFileName` on Windows, GTK on Linux) and would block the driver. The buttons are still required to be present.
- Forcing a specific barcode into a live camera frame. Detection depends on what the webcam sees.

## Official integration_test (iOS / multi-simulator)

The newer suite lives under `example/integration_test/` and is driven with:

```bash
cd example
flutter test integration_test/plugin_integration_test.dart -d <simulator-id>
# or
flutter drive --driver=test_driver/integration_test.dart \
  --target=integration_test/plugin_integration_test.dart -d <simulator-id>
```

It covers encode/decode, rowStride, camera list/init/error paths, torch,
controller validation, and example UI smoke. Live camera barcode detection is
not asserted (Simulator camera/permission variability).
