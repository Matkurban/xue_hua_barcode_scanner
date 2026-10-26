# xue_hua_barcode_scanner_example

Demonstrates how to use the xue_hua_barcode_scanner plugin.

## Driver tests

Acceptance target is Windows desktop. From this directory:

```bash
flutter drive -d windows --target=test_driver/app.dart
```

Linux (including a machine with no camera) uses the same target:

```bash
flutter drive -d linux --target=test_driver/app.dart
```

Headless Linux:

```bash
xvfb-run -a flutter drive -d linux --target=test_driver/app.dart
```

What the suite covers, and why the OS gallery picker is skipped, is in [test_driver/README.md](test_driver/README.md).

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
