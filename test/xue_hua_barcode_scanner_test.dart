import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:xue_hua_barcode_scanner/xue_hua_barcode_scanner.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('encodeBarcode and decodeImageMemory round-trip succeeds', () async {
    const String payload =
        'https://github.com/Matkurban/xue_hua_barcode_scanner';
    final Uint8List pngBytes = await XueHuaBarcodeScanner.encodeBarcode(
      payload,
      width: 256,
      height: 256,
      margin: 2,
      eccLevel: BarcodeEccLevel.high,
    );
    expect(pngBytes, isNotEmpty);

    final List<BarcodeResult> results =
        await XueHuaBarcodeScanner.decodeImageMemory(pngBytes);
    expect(results, isNotEmpty);
    expect(results.first.text, equals(payload));
    expect(results.first.format, equals(BarcodeFormat.qrCode));
    expect(results.first.cornerPoints.length, equals(4));
    expect(results.first.isValid, isTrue);
  });

  testWidgets(
    'XueHuaBarcodeScannerPage renders XueHuaScannerTexts and turns red on validation failure',
    (WidgetTester tester) async {
      final XueHuaScannerController controller = XueHuaScannerController(
        validator: (BarcodeResult result) => result.text.startsWith('https://'),
        engine: _ScriptedCameraEngine(const <CameraInputSource>[
          CameraInputSource(
            id: 'back',
            label: '后置相机',
            facing: CameraFacing.back,
          ),
          CameraInputSource(
            id: 'front',
            label: '前置相机',
            facing: CameraFacing.front,
          ),
        ]),
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: XueHuaBarcodeScannerPage(
            controller: controller,
            texts: const XueHuaScannerTexts(
              hintText: 'Scan QR Code',
              invalidBarcodeText: 'Invalid QR Code',
              torchOffLabel: 'Flash',
              galleryLabel: 'Photos',
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Scan QR Code'), findsOneWidget);
      expect(find.text('Flash'), findsOneWidget);
      expect(find.text('Photos'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('xh_scanner_switch_camera_button')),
        findsOneWidget,
      );

      await tester.runAsync(() async {
        await controller.simulateBarcodeDetection('INVALID_PAYLOAD');
      });
      await tester.pump();

      expect(controller.value.hasValidationError, isTrue);
      expect(find.text('Invalid QR Code'), findsOneWidget);

      controller.clearValidationError();
      await tester.pump();
      expect(controller.value.hasValidationError, isFalse);
      expect(find.text('Scan QR Code'), findsOneWidget);
    },
  );

  testWidgets('single input source hides the camera menu button', (
    WidgetTester tester,
  ) async {
    final _ScriptedCameraEngine engine = _ScriptedCameraEngine(
      const <CameraInputSource>[
        CameraInputSource(id: 'only', label: '内置相机', facing: CameraFacing.back),
      ],
    );
    final XueHuaScannerController controller = XueHuaScannerController(
      engine: engine,
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(home: XueHuaBarcodeScannerPage(controller: controller)),
    );
    await tester.pump();

    expect(engine.openedCameraId, 'only');
    expect(
      find.byKey(const ValueKey<String>('xh_scanner_switch_camera_button')),
      findsNothing,
    );
    expect(find.text('内置相机'), findsNothing);
  });

  testWidgets('multiple input sources open the menu only after the user taps', (
    WidgetTester tester,
  ) async {
    const CameraInputSource backCamera = CameraInputSource(
      id: 'back',
      label: '后置相机',
      facing: CameraFacing.back,
    );
    const CameraInputSource frontCamera = CameraInputSource(
      id: 'front',
      label: '前置相机',
      facing: CameraFacing.front,
    );
    final _ScriptedCameraEngine engine = _ScriptedCameraEngine(
      const <CameraInputSource>[backCamera, frontCamera],
    );
    final XueHuaScannerController controller = XueHuaScannerController(
      initialFacing: CameraFacing.back,
      engine: engine,
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(home: XueHuaBarcodeScannerPage(controller: controller)),
    );
    await tester.pump();

    expect(controller.value.activeCameraId, 'back');
    expect(find.text('后置相机'), findsNothing);
    expect(find.text('前置相机'), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('xh_scanner_switch_camera_button')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('xh_scanner_switch_camera_button')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('后置相机'), findsOneWidget);
    expect(find.text('前置相机'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey<String>('xh_scanner_camera_source_front')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(controller.value.activeCameraId, 'front');
    expect(controller.value.cameraFacing, CameraFacing.front);
    expect(engine.openedCameraId, 'front');
    expect(find.text('前置相机'), findsNothing);
  });
}

class _ScriptedCameraEngine implements XueHuaScannerPlatformEngine {
  _ScriptedCameraEngine(this.cameras);

  final List<CameraInputSource> cameras;
  String? openedCameraId;

  CameraInputSource _resolve(CameraFacing facing, String? cameraId) {
    if (cameraId != null) {
      for (final CameraInputSource camera in cameras) {
        if (camera.id == cameraId) {
          return camera;
        }
      }
    }
    for (final CameraInputSource camera in cameras) {
      if (camera.facing == facing) {
        return camera;
      }
    }
    return cameras.first;
  }

  ScannerState _stateFor(CameraFacing facing, String? cameraId) {
    final CameraInputSource active = _resolve(facing, cameraId);
    openedCameraId = active.id;
    return ScannerState(
      isInitialized: true,
      isRunning: true,
      cameraFacing: active.facing,
      cameras: cameras,
      availableCameraCount: cameras.length,
      activeCameraId: active.id,
    );
  }

  @override
  String get engineVersion => 'test';

  @override
  bool get isWeb => false;

  @override
  Future<List<CameraInputSource>> listCameras() async => cameras;

  @override
  Future<ScannerState> startCamera({
    required CameraFacing facing,
    String? cameraId,
    required void Function(CameraFramePacket frame) onFrame,
    required void Function(List<BarcodeResult> results) onWebBarcodes,
  }) async {
    return _stateFor(facing, cameraId);
  }

  @override
  Future<ScannerState> switchCamera({
    required CameraFacing targetFacing,
    required void Function(CameraFramePacket frame) onFrame,
    required void Function(List<BarcodeResult> results) onWebBarcodes,
  }) {
    return startCamera(
      facing: targetFacing,
      onFrame: onFrame,
      onWebBarcodes: onWebBarcodes,
    );
  }

  @override
  Future<void> stopCamera() async {}

  @override
  Future<TorchState> setTorch(bool enabled) async => TorchState.unavailable;

  @override
  Future<Uint8List?> pickImageFromGallery() async => null;

  @override
  Future<List<BarcodeResult>> decodeImageBytes(
    Uint8List rawPixelBytes, {
    required int width,
    required int height,
    int rowStride = 0,
    PixelFormat format = PixelFormat.rgba8888,
    bool tryHarder = true,
    bool tryRotate = true,
    bool tryInvert = true,
  }) async {
    return const <BarcodeResult>[];
  }

  @override
  Future<List<BarcodeResult>> decodeImageFile(
    String filePath, {
    bool tryHarder = true,
    bool tryRotate = true,
    bool tryInvert = true,
  }) async {
    return const <BarcodeResult>[];
  }

  @override
  Future<List<BarcodeResult>> decodeImageMemory(
    Uint8List encodedImageBytes, {
    bool tryHarder = true,
    bool tryRotate = true,
    bool tryInvert = true,
  }) async {
    return const <BarcodeResult>[];
  }

  @override
  Future<Uint8List> encodeBarcode(
    String content, {
    int width = 512,
    int height = 512,
    int margin = 2,
    BarcodeEccLevel eccLevel = BarcodeEccLevel.medium,
  }) async {
    return Uint8List(0);
  }
}
