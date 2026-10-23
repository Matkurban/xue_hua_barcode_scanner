// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';
import 'dart:ui' show Offset, Size;

import '../models/barcode_enums.dart';
import '../models/barcode_result.dart';
import 'web_js_interop.dart';

/// Attempts to decode barcodes on Web using `window.ZXingWasm`.
Future<List<BarcodeResult>> tryDecodeWithZxingWasm(
  Uint8List rgbaBytes, {
  required int width,
  required int height,
  required bool tryHarder,
  required bool tryRotate,
  required bool tryInvert,
}) async {
  if (!jsWindow.has('ZXingWasm')) {
    return const <BarcodeResult>[];
  }
  try {
    final JSObject? zxingWasm =
        jsWindow.getProperty<JSObject?>('ZXingWasm'.toJS);
    if (zxingWasm == null || !zxingWasm.has('readBarcodesFromImageData')) {
      return const <BarcodeResult>[];
    }

    Future<List<BarcodeResult>> runPass(Uint8List buffer) async {
      final JSObject canvas = createDomElement('canvas');
      canvas.setProperty('width'.toJS, width.toJS);
      canvas.setProperty('height'.toJS, height.toJS);
      final JSObject? ctx =
          canvas.callMethod<JSObject?>('getContext'.toJS, '2d'.toJS);
      if (ctx == null) return const <BarcodeResult>[];

      final JSObject imageData = ctx.callMethodVarArgs<JSObject>(
        'createImageData'.toJS,
        <JSAny?>[width.toJS, height.toJS],
      );
      final JSUint8ClampedArray? dstData =
          imageData.getProperty<JSUint8ClampedArray?>('data'.toJS);
      dstData?.toDart.setAll(0, buffer);

      final JSObject readerOptions = JSObject();
      readerOptions.setProperty('tryHarder'.toJS, tryHarder.toJS);
      readerOptions.setProperty('tryRotate'.toJS, tryRotate.toJS);
      readerOptions.setProperty('tryInvert'.toJS, tryInvert.toJS);
      readerOptions.setProperty('tryDenoise'.toJS, true.toJS);

      final JSPromise<JSArray<JSObject>> promise =
          zxingWasm.callMethodVarArgs<JSPromise<JSArray<JSObject>>>(
        'readBarcodesFromImageData'.toJS,
        <JSAny?>[imageData, readerOptions],
      );
      final List<JSObject> items = (await promise.toDart).toDart;
      return parseJsBarcodeResults(items, width: width, height: height);
    }

    final List<BarcodeResult> direct = await runPass(rgbaBytes);
    if (direct.isNotEmpty || !tryHarder || width < 48 || height < 48) {
      return direct;
    }

    final Uint8List dilated = dilateDarkDotsRgba3x3(
      rgbaBytes,
      width: width,
      height: height,
    );
    return await runPass(dilated);
  } catch (_) {
    return const <BarcodeResult>[];
  }
}

/// Attempts to decode barcodes on Web using the browser's `BarcodeDetector` API.
Future<List<BarcodeResult>> tryDecodeWithBrowserBarcodeDetector(
  Uint8List rgbaBytes, {
  required int width,
  required int height,
}) async {
  if (!jsWindow.has('BarcodeDetector')) {
    return const <BarcodeResult>[];
  }
  try {
    Future<List<BarcodeResult>> runDetectorPass(Uint8List buffer) async {
      final JSObject canvas = createDomElement('canvas');
      canvas.setProperty('width'.toJS, width.toJS);
      canvas.setProperty('height'.toJS, height.toJS);
      final JSObject? ctx =
          canvas.callMethod<JSObject?>('getContext'.toJS, '2d'.toJS);
      if (ctx == null) return const <BarcodeResult>[];

      final JSObject imageData = ctx.callMethodVarArgs<JSObject>(
        'createImageData'.toJS,
        <JSAny?>[width.toJS, height.toJS],
      );
      final JSUint8ClampedArray? dstData =
          imageData.getProperty<JSUint8ClampedArray?>('data'.toJS);
      dstData?.toDart.setAll(0, buffer);
      ctx.callMethodVarArgs<JSAny?>(
        'putImageData'.toJS,
        <JSAny?>[imageData, 0.toJS, 0.toJS],
      );

      final JSObject detector = jsWindow.callMethod<JSObject>(
        'eval'.toJS,
        'new BarcodeDetector()'.toJS,
      );
      final JSPromise<JSArray<JSObject>> detectPromise = detector
          .callMethod<JSPromise<JSArray<JSObject>>>('detect'.toJS, canvas);
      final List<JSObject> detected = (await detectPromise.toDart).toDart;
      return parseJsBarcodeResults(detected, width: width, height: height);
    }

    final List<BarcodeResult> direct = await runDetectorPass(rgbaBytes);
    if (direct.isNotEmpty || width < 48 || height < 48) {
      return direct;
    }

    final Uint8List dilated = dilateDarkDotsRgba3x3(
      rgbaBytes,
      width: width,
      height: height,
    );
    return await runDetectorPass(dilated);
  } catch (_) {
    return const <BarcodeResult>[];
  }
}

/// Converts JS barcode objects returned by `ZXingWasm` or `BarcodeDetector` into [BarcodeResult]s.
List<BarcodeResult> parseJsBarcodeResults(
  List<JSObject> items, {
  required int width,
  required int height,
}) {
  final List<BarcodeResult> results = <BarcodeResult>[];
  for (final JSObject obj in items) {
    final String text =
        (obj.getProperty<JSAny?>('text'.toJS)?.dartify()?.toString()) ??
            (obj.getProperty<JSAny?>('rawValue'.toJS)?.dartify()?.toString()) ??
            '';
    if (text.isEmpty) continue;

    final String formatStr =
        (obj.getProperty<JSAny?>('format'.toJS)?.dartify()?.toString()) ??
            'qr_code';
    final List<Offset> corners = <Offset>[];

    if (obj.has('cornerPoints')) {
      final JSArray<JSObject>? pts =
          obj.getProperty<JSArray<JSObject>?>('cornerPoints'.toJS);
      if (pts != null) {
        for (final JSObject pt in pts.toDart) {
          final double x =
              (pt.getProperty<JSNumber?>('x'.toJS)?.toDartDouble) ?? 0;
          final double y =
              (pt.getProperty<JSNumber?>('y'.toJS)?.toDartDouble) ?? 0;
          corners.add(Offset(x, y));
        }
      }
    } else if (obj.has('position')) {
      final JSObject? pos = obj.getProperty<JSObject?>('position'.toJS);
      if (pos != null) {
        for (final String key in <String>[
          'topLeft',
          'topRight',
          'bottomRight',
          'bottomLeft',
        ]) {
          final JSObject? pt = pos.getProperty<JSObject?>(key.toJS);
          if (pt != null) {
            final double x =
                (pt.getProperty<JSNumber?>('x'.toJS)?.toDartDouble) ?? 0;
            final double y =
                (pt.getProperty<JSNumber?>('y'.toJS)?.toDartDouble) ?? 0;
            corners.add(Offset(x, y));
          }
        }
      }
    }

    results.add(
      BarcodeResult(
        text: text,
        rawBytes: Uint8List.fromList(utf8.encode(text)),
        cornerPoints: corners.isNotEmpty
            ? corners
            : <Offset>[
                Offset(width * 0.2, height * 0.2),
                Offset(width * 0.8, height * 0.2),
                Offset(width * 0.8, height * 0.8),
                Offset(width * 0.2, height * 0.8),
              ],
        format: BarcodeFormat.fromString(formatStr),
        isValid: true,
        frameSize: Size(width.toDouble(), height.toDouble()),
      ),
    );
  }
  return results;
}
