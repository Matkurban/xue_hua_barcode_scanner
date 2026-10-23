import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:xue_hua_barcode_scanner/xue_hua_barcode_scanner.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('encodeBarcode and decodeImageMemory round-trip succeeds', () async {
    const String payload = 'https://github.com/Matkurban/xue_hua_barcode_scanner';
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
  });
}
