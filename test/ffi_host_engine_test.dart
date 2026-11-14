import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:xue_hua_barcode_scanner/xue_hua_barcode_scanner.dart';

Future<Uint8List> _pngToLumaBytes(
  Uint8List pngBytes, {
  required int width,
  required int height,
}) async {
  final ui.Codec codec = await ui.instantiateImageCodec(pngBytes);
  final ui.FrameInfo frame = await codec.getNextFrame();
  final ByteData? byteData = await frame.image.toByteData(
    format: ui.ImageByteFormat.rawRgba,
  );
  frame.image.dispose();
  codec.dispose();
  expect(byteData, isNotNull);

  final Uint8List rgba = byteData!.buffer.asUint8List();
  final Uint8List luma = Uint8List(width * height);
  for (int i = 0; i < width * height; i++) {
    final int r = rgba[i * 4];
    final int g = rgba[i * 4 + 1];
    final int b = rgba[i * 4 + 2];
    luma[i] = (r * 77 + g * 150 + b * 29) >> 8;
  }
  return luma;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'unbound FFI engine handles full lifecycle without platform channels',
    () async {
      final XueHuaScannerPlatformEngine engine = XueHuaBarcodeScanner.engine;
      expect(engine.isWeb, isFalse);
      expect(engine.engineVersion, isNotEmpty);

      final List<CameraInputSource> cameras = await engine.listCameras();
      expect(cameras, isNotEmpty);

      final ScannerState started = await engine.startCamera(
        facing: CameraFacing.back,
        onFrame: (_) {},
        onWebBarcodes: (_) {},
      );
      expect(started.isInitialized, isTrue);
      expect(started.isRunning, isTrue);
      expect(started.errorCode, isNull);

      final bool openedSettings = await engine.openAppSettings();
      expect(openedSettings, isFalse);

      final Uint8List? galleryBytes = await engine.pickImageFromGallery();
      expect(galleryBytes, isNull);

      final TorchState torchState = await engine.setTorch(true);
      final bool isDesktop =
          Platform.isMacOS || Platform.isWindows || Platform.isLinux;
      expect(
        torchState,
        equals(isDesktop ? TorchState.unavailable : TorchState.on),
      );

      final ScannerState switched = await engine.switchCamera(
        targetFacing: cameras.last.facing,
        onFrame: (_) {},
        onWebBarcodes: (_) {},
      );
      expect(switched.isInitialized, isTrue);
      expect(switched.isRunning, isTrue);

      await engine.stopCamera();
      await engine.dispose();
    },
  );

  test(
    'controller with pure FFI engine decodes luma frames and disposes cleanly',
    () async {
      const String payload = 'xue_hua_pure_ffi_round_trip_2026';
      const int size = 256;
      final Uint8List pngBytes = await XueHuaBarcodeScanner.encodeBarcode(
        payload,
        width: size,
        height: size,
        margin: 4,
        eccLevel: BarcodeEccLevel.high,
      );
      final Uint8List lumaBytes = await _pngToLumaBytes(
        pngBytes,
        width: size,
        height: size,
      );

      final Completer<List<BarcodeResult>> detected =
          Completer<List<BarcodeResult>>();
      final XueHuaScannerController controller = XueHuaScannerController(
        scanInterval: Duration.zero,
        onDetect: (List<BarcodeResult> results) {
          if (!detected.isCompleted && results.isNotEmpty) {
            detected.complete(results);
          }
        },
      );

      await controller.start();
      expect(controller.value.isRunning, isTrue);

      await controller.pause();
      expect(controller.value.isPaused, isTrue);

      await controller.resume();
      expect(controller.value.isPaused, isFalse);

      await controller.processCameraFrame(
        CameraFramePacket(
          bytes: lumaBytes,
          width: size,
          height: size,
          rowStride: size,
          format: PixelFormat.lum,
          sensorOrientation: 0,
        ),
      );

      final List<BarcodeResult> decoded = await detected.future;
      expect(decoded.first.text, equals(payload));
      expect(decoded.first.format, equals(BarcodeFormat.qrCode));

      final bool settingsResult = await controller.openAppSettings();
      expect(settingsResult, isFalse);

      await controller.stop();
      expect(controller.value.isRunning, isFalse);

      controller.dispose();
    },
  );
}
