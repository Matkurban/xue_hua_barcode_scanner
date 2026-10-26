# Example driver tests

Classic `flutter_driver` smoke for the example app on the Linux desktop. The instrumented entry is `test_driver/app.dart` (`enableFlutterDriverExtension`). Everyday `flutter run` still uses `lib/main.dart` and does not install the extension.

## Run

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
- Missing camera: the page stays up. The test accepts either the error placeholder (`相机不可用` / `NO_CAMERA` / `No V4L2`) or a live preview placeholder (`取景`). A real texture (no status label) is also treated as success. Torch either toggles or shows the unsupported snackbar.

## Intentionally skipped

- Tapping **从相册选图解码** or the scanner gallery button. On Linux, `pickImageFilePath` runs a modal GTK file chooser on the platform thread and would block the driver.
- A real camera stream. The Linux embedder reports `NO_CAMERA` when no V4L2 device is opened, which is normal on a box without `/dev/video*`.
