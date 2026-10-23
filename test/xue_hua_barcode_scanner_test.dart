import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xue_hua_barcode_scanner/xue_hua_barcode_scanner.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('encodeQrCode and decodeImageMemory round-trip succeeds', () async {
    const String payload = 'https://github.com/Matkurban/xue_hua_barcode_scanner';
    final Uint8List pngBytes = await XueHuaBarcodeScanner.encodeQrCode(
      payload,
      width: 256,
      height: 256,
      margin: 2,
      eccLevel: QrEccLevel.high,
    );
    expect(pngBytes, isNotEmpty);

    final List<QrCodeResult> results =
        await XueHuaBarcodeScanner.decodeImageMemory(pngBytes);
    expect(results, isNotEmpty);
    expect(results.first.text, equals(payload));
    expect(results.first.format, equals(BarcodeFormat.qrCode));
    expect(results.first.cornerPoints.length, equals(4));
    expect(results.first.isValid, isTrue);
  });

  testWidgets('XueHuaQrScannerPage renders default prompt and action buttons',
      (WidgetTester tester) async {
    final XueHuaScannerController controller = XueHuaScannerController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: XueHuaQrScannerPage(
          controller: controller,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('将二维码放入框内'), findsOneWidget);
    expect(find.text('手电筒'), findsOneWidget);
    expect(find.text('相册'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('xh_scanner_switch_camera_button')),
      findsOneWidget,
    );
  });
}
