import 'dart:convert';
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
    'Custom default UI renders default texts, full-screen overlay, and action buttons',
    (WidgetTester tester) async {
      final ScannerController controller = ScannerController(
        engine: _ScriptedCameraEngine(const <CameraInputSource>[
          CameraInputSource(
            id: 'back',
            label: '后置相机',
            facing: CameraFacing.back,
          ),
        ]),
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(home: BarcodeScannerPage(controller: controller)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('扫二维码 / 条码'), findsOneWidget);
      expect(find.text('轻触照亮'), findsOneWidget);
      expect(find.text('相册'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('xh_scanner_back_button')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('xh_scanner_torch_button')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('xh_scanner_gallery_button')),
        findsOneWidget,
      );

      final ScannerOverlay overlay = tester.widget<ScannerOverlay>(
        find.byType(ScannerOverlay),
      );
      expect(overlay.showCutout, isFalse);
      expect(overlay.cornerColor, equals(const Color(0xFF07C160)));
    },
  );

  testWidgets(
    'multi-barcode detection freezes preview, renders Custom green markers, and supports manual selection or cancel',
    (WidgetTester tester) async {
      final _ScriptedCameraEngine engine = _ScriptedCameraEngine(
        const <CameraInputSource>[
          CameraInputSource(
            id: 'back',
            label: '后置相机',
            facing: CameraFacing.back,
          ),
        ],
      );
      final List<List<BarcodeResult>> detectedBatches = <List<BarcodeResult>>[];
      final List<BarcodeResult> selectedBarcodes = <BarcodeResult>[];

      final ScannerController controller = ScannerController(
        engine: engine,
        onDetect: detectedBatches.add,
        onBarcodeSelected: selectedBarcodes.add,
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(home: BarcodeScannerPage(controller: controller)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      const Size frameSize = Size(800, 600);
      final List<BarcodeResult> twoCodes = <BarcodeResult>[
        BarcodeResult(
          text: 'WECHAT-CODE-1',
          rawBytes: Uint8List.fromList(utf8.encode('WECHAT-CODE-1')),
          cornerPoints: const <Offset>[
            Offset(120, 140),
            Offset(220, 140),
            Offset(220, 240),
            Offset(120, 240),
          ],
          format: BarcodeFormat.qrCode,
          frameSize: frameSize,
        ),
        BarcodeResult(
          text: 'WECHAT-CODE-2',
          rawBytes: Uint8List.fromList(utf8.encode('WECHAT-CODE-2')),
          cornerPoints: const <Offset>[
            Offset(520, 320),
            Offset(620, 320),
            Offset(620, 420),
            Offset(520, 420),
          ],
          format: BarcodeFormat.qrCode,
          frameSize: frameSize,
        ),
      ];

      await controller.simulateMultiBarcodeDetection(twoCodes);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(controller.value.isPaused, isTrue);
      expect(controller.value.isSelectingMultiBarcode, isTrue);
      expect(engine.streamPaused, isTrue);
      expect(detectedBatches, isEmpty);
      expect(selectedBarcodes, isEmpty);

      expect(find.text('轻触小绿点，选择要识别的码'), findsOneWidget);
      expect(
        find.byKey(
          const ValueKey<String>('xh_scanner_cancel_multi_select_button'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('xh_scanner_barcode_marker_0')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('xh_scanner_barcode_marker_1')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('xh_scanner_barcode_marker_1')),
      );
      await tester.pump();

      expect(controller.value.isSelectingMultiBarcode, isFalse);
      expect(detectedBatches.length, equals(1));
      expect(detectedBatches.first.single.text, equals('WECHAT-CODE-2'));
      expect(selectedBarcodes.length, equals(1));
      expect(selectedBarcodes.first.text, equals('WECHAT-CODE-2'));

      await controller.simulateMultiBarcodeDetection(twoCodes);
      await tester.pump();
      expect(controller.value.isSelectingMultiBarcode, isTrue);

      await tester.tap(
        find.byKey(
          const ValueKey<String>('xh_scanner_cancel_multi_select_button'),
        ),
      );
      await tester.pump();

      expect(controller.value.isSelectingMultiBarcode, isFalse);
      expect(controller.value.isPaused, isFalse);
      expect(engine.streamPaused, isFalse);
      expect(find.text('扫二维码 / 条码'), findsOneWidget);
    },
  );

  testWidgets(
    'barcodeMarkerBuilder renders custom widget at exact mapped barcode coordinates and triggers selection',
    (WidgetTester tester) async {
      final _ScriptedCameraEngine engine = _ScriptedCameraEngine(
        const <CameraInputSource>[
          CameraInputSource(
            id: 'back',
            label: '后置相机',
            facing: CameraFacing.back,
          ),
        ],
      );
      final List<BarcodeMarkerInfo> capturedMarkerInfos = <BarcodeMarkerInfo>[];
      BarcodeResult? selectedByCustomMarker;

      final ScannerController controller = ScannerController(engine: engine);
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: BarcodeScannerPage(
            controller: controller,
            onBarcodeSelected: (BarcodeResult result) {
              selectedByCustomMarker = result;
            },
            barcodeMarkerBuilder:
                (
                  BuildContext context,
                  BarcodeMarkerInfo info,
                  VoidCallback onSelect,
                ) {
                  capturedMarkerInfos.add(info);
                  return GestureDetector(
                    key: ValueKey<String>('custom_marker_btn_${info.index}'),
                    onTap: onSelect,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      color: Colors.cyanAccent,
                      child: Text('码#${info.index}:${info.result.text}'),
                    ),
                  );
                },
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      const Size frameSize = Size(800, 600);
      await controller.simulateMultiBarcodeDetection(<BarcodeResult>[
        BarcodeResult(
          text: 'CUSTOM-A',
          rawBytes: Uint8List.fromList(utf8.encode('CUSTOM-A')),
          cornerPoints: const <Offset>[
            Offset(100, 100),
            Offset(200, 100),
            Offset(200, 200),
            Offset(100, 200),
          ],
          format: BarcodeFormat.qrCode,
          frameSize: frameSize,
        ),
        BarcodeResult(
          text: 'CUSTOM-B',
          rawBytes: Uint8List.fromList(utf8.encode('CUSTOM-B')),
          cornerPoints: const <Offset>[
            Offset(500, 300),
            Offset(600, 300),
            Offset(600, 400),
            Offset(500, 400),
          ],
          format: BarcodeFormat.qrCode,
          frameSize: frameSize,
        ),
      ]);
      await tester.pump();

      expect(capturedMarkerInfos.length, greaterThanOrEqualTo(2));
      expect(capturedMarkerInfos[0].center, equals(const Offset(150, 150)));
      expect(
        capturedMarkerInfos[0].boundingBox,
        equals(const Rect.fromLTRB(100, 100, 200, 200)),
      );
      expect(capturedMarkerInfos[1].center, equals(const Offset(550, 350)));
      expect(capturedMarkerInfos[1].isMultiSelectMode, isTrue);

      expect(find.text('码#0:CUSTOM-A'), findsOneWidget);
      expect(find.text('码#1:CUSTOM-B'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey<String>('custom_marker_btn_0')),
      );
      await tester.pump();

      expect(selectedByCustomMarker, isNotNull);
      expect(selectedByCustomMarker!.text, equals('CUSTOM-A'));
      expect(controller.value.isSelectingMultiBarcode, isFalse);
    },
  );

  testWidgets(
    'XueHuaBarcodeScannerPage renders XueHuaScannerTexts and turns red on validation failure',
    (WidgetTester tester) async {
      final ScannerController controller = ScannerController(
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
          home: BarcodeScannerPage(
            controller: controller,
            texts: const ScannerTexts(
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
    final ScannerController controller = ScannerController(engine: engine);
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(home: BarcodeScannerPage(controller: controller)),
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
    final ScannerController controller = ScannerController(
      initialFacing: CameraFacing.back,
      engine: engine,
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(home: BarcodeScannerPage(controller: controller)),
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

  testWidgets(
    'camera permission denied renders dedicated recovery view and supports retry',
    (WidgetTester tester) async {
      final _PermissionToggleCameraEngine engine =
          _PermissionToggleCameraEngine(initiallyDenied: true);
      final ScannerController controller = ScannerController(engine: engine);
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(home: BarcodeScannerPage(controller: controller)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(controller.value.isPermissionDenied, isTrue);
      expect(
        find.byKey(const ValueKey<String>('xh_scanner_permission_denied_view')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('xh_scanner_open_settings_button')),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey<String>('xh_scanner_retry_permission_button'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey<String>('xh_scanner_permission_gallery_button'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('xh_scanner_camera_status')),
        findsOneWidget,
      );

      // Grant permission and tap retry button.
      engine.initiallyDenied = false;
      await tester.tap(
        find.byKey(
          const ValueKey<String>('xh_scanner_retry_permission_button'),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(controller.value.isPermissionDenied, isFalse);
      expect(controller.value.isRunning, isTrue);
      expect(
        find.byKey(const ValueKey<String>('xh_scanner_permission_denied_view')),
        findsNothing,
      );
    },
  );
}

class _PermissionToggleCameraEngine extends _ScriptedCameraEngine {
  _PermissionToggleCameraEngine({required this.initiallyDenied})
    : super(const <CameraInputSource>[
        CameraInputSource(id: 'back', label: '后置相机', facing: CameraFacing.back),
      ]);

  bool initiallyDenied;

  @override
  Future<ScannerState> startCamera({
    required CameraFacing facing,
    String? cameraId,
    required void Function(CameraFramePacket frame) onFrame,
    required void Function(List<BarcodeResult> results) onWebBarcodes,
  }) async {
    if (initiallyDenied) {
      return const ScannerState(
        isInitialized: true,
        isRunning: false,
        permissionStatus: CameraPermissionStatus.denied,
        errorCode: 'CAMERA_PERMISSION_DENIED',
        errorMessage: 'Camera permission was denied by the user.',
      );
    }
    return super.startCamera(
      facing: facing,
      cameraId: cameraId,
      onFrame: onFrame,
      onWebBarcodes: onWebBarcodes,
    );
  }
}

class _ScriptedCameraEngine implements ScannerPlatformEngine {
  _ScriptedCameraEngine(this.cameras);

  final List<CameraInputSource> cameras;
  String? openedCameraId;
  bool streamPaused = false;

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
    streamPaused = false;
    return ScannerState(
      isInitialized: true,
      isRunning: true,
      cameraFacing: active.facing,
      cameras: cameras,
      availableCameraCount: cameras.length,
      activeCameraId: active.id,
      permissionStatus: CameraPermissionStatus.granted,
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
  Future<bool> openAppSettings() async => false;

  @override
  Future<void> setStreamPaused(bool paused) async {
    streamPaused = paused;
  }

  @override
  Future<void> dispose() async {}

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
