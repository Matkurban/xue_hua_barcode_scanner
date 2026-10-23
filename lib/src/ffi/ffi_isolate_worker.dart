import 'dart:convert';
import 'dart:ffi' as ffi;
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show Offset, Size;

import 'package:ffi/ffi.dart';

import '../core/barcode_matrix_codec.dart';
import '../models/barcode_enums.dart';
import '../models/barcode_result.dart';
import 'row_stride_normalizer.dart';
import 'zxing_ffi_bindings.dart';

const String _kLibName = 'xue_hua_barcode_scanner';

/// Opens the platform-specific dynamic library containing `zxing-cpp` C symbols.
ffi.DynamicLibrary? tryOpenZxingDynamicLibrary() {
  try {
    if (Platform.isMacOS || Platform.isIOS) {
      final ffi.DynamicLibrary processLib = ffi.DynamicLibrary.process();
      if (processLib.providesSymbol('zxing_decode_image_bytes')) {
        return processLib;
      }
      final ffi.DynamicLibrary execLib = ffi.DynamicLibrary.executable();
      if (execLib.providesSymbol('zxing_decode_image_bytes')) {
        return execLib;
      }
      final String debugDylibPath =
          '${Platform.resolvedExecutable}.debug.dylib';
      if (File(debugDylibPath).existsSync()) {
        final ffi.DynamicLibrary debugLib = ffi.DynamicLibrary.open(
          debugDylibPath,
        );
        if (debugLib.providesSymbol('zxing_decode_image_bytes')) {
          return debugLib;
        }
      }
      try {
        final ffi.DynamicLibrary frameworkLib = ffi.DynamicLibrary.open(
          '$_kLibName.framework/$_kLibName',
        );
        if (frameworkLib.providesSymbol('zxing_decode_image_bytes')) {
          return frameworkLib;
        }
      } catch (_) {}
      return null;
    }
    if (Platform.isAndroid || Platform.isLinux) {
      return ffi.DynamicLibrary.open('lib$_kLibName.so');
    }
    if (Platform.isWindows) {
      return ffi.DynamicLibrary.open('$_kLibName.dll');
    }
  } catch (_) {
    return null;
  }
  return null;
}

/// Reads the underlying native engine version string via FFI.
String readNativeEngineVersion() {
  final ffi.DynamicLibrary? dylib = tryOpenZxingDynamicLibrary();
  if (dylib != null) {
    try {
      final ZxingFfiBindings bindings = ZxingFfiBindings(dylib);
      final ffi.Pointer<ffi.Char> ptr = bindings.zxing_engine_version();
      if (ptr != ffi.nullptr) {
        return ptr.cast<Utf8>().toDartString();
      }
    } catch (_) {}
  }
  return 'zxing-cpp 3.1.1 (FFI Isolate Worker)';
}

/// Executes native `zxing_decode_image_bytes` inside a background worker `Isolate`
/// and guarantees native heap cleanup via `free_barcode_results`.
List<BarcodeResult> decodeInWorkerIsolate({
  required Uint8List rawPixelBytes,
  required int width,
  required int height,
  required int rowStride,
  required PixelFormat format,
  required bool tryHarder,
  required bool tryRotate,
  required bool tryInvert,
}) {
  final ffi.DynamicLibrary? dylib = tryOpenZxingDynamicLibrary();
  if (dylib != null) {
    try {
      final ZxingFfiBindings bindings = ZxingFfiBindings(dylib);
      final int bpp = format.bytesPerPixel;
      final int effectiveStride = rowStride > 0 ? rowStride : (width * bpp);
      final int requiredBytes = effectiveStride * height;

      final Uint8List safePixels = rawPixelBytes.length < requiredBytes
          ? normalizeRowStrideBuffer(
              rawPixelBytes,
              width: width,
              height: height,
              rowStride: rowStride,
              format: format,
            )
          : rawPixelBytes;
      final int passedStride = safePixels.length == width * bpp * height
          ? (width * bpp)
          : effectiveStride;

      final ffi.Pointer<ffi.Uint8> nativePixels = calloc<ffi.Uint8>(
        safePixels.length,
      );
      ffi.Pointer<CBarcodeResultList> resultListPtr = ffi.nullptr;

      try {
        nativePixels.asTypedList(safePixels.length).setAll(0, safePixels);
        resultListPtr = bindings.zxing_decode_image_bytes(
          nativePixels,
          width,
          height,
          passedStride,
          format.cValue,
          tryHarder ? 1 : 0,
          tryRotate ? 1 : 0,
          tryInvert ? 1 : 0,
        );

        if (resultListPtr != ffi.nullptr) {
          final CBarcodeResultList listStruct = resultListPtr.ref;
          final int count = listStruct.count;
          final List<BarcodeResult> parsed = <BarcodeResult>[];
          for (int i = 0; i < count; i++) {
            final CBarcodeResult item = (listStruct.results + i).ref;
            final String text = item.text == ffi.nullptr
                ? ''
                : item.text.cast<Utf8>().toDartString();
            final int rawLen = item.raw_bytes_length;
            final Uint8List rawBytes =
                (item.raw_bytes != ffi.nullptr && rawLen > 0)
                ? Uint8List.fromList(item.raw_bytes.asTypedList(rawLen))
                : Uint8List.fromList(utf8.encode(text));

            final int cornerCount = item.corner_points_count.clamp(0, 4);
            final List<Offset> corners = <Offset>[];
            for (int c = 0; c < cornerCount; c++) {
              final CBarcodePoint pt = item.corner_points[c];
              corners.add(Offset(pt.x, pt.y));
            }

            parsed.add(
              BarcodeResult(
                text: text,
                rawBytes: rawBytes,
                cornerPoints: corners,
                format: BarcodeFormat.fromCValue(item.format),
                isValid: item.is_valid != 0,
                frameSize: Size(width.toDouble(), height.toDouble()),
              ),
            );
          }
          if (parsed.isNotEmpty) {
            return parsed;
          }
        }
      } finally {
        if (resultListPtr != ffi.nullptr) {
          bindings.free_barcode_results(resultListPtr);
        }
        calloc.free(nativePixels);
      }
    } catch (_) {
      // Fall through to deterministic fallback matrix decoder if FFI lookup fails.
    }
  }

  return BarcodeMatrixCodec.tryDecodeFallbackMatrix(
    rawPixelBytes,
    width: width,
    height: height,
    rowStride: rowStride,
    format: format,
  );
}

/// Executes native `zxing_encode_barcode` inside a background worker `Isolate`
/// and guarantees native heap cleanup via `free_encoded_barcode_image`.
Uint8List encodeRgbaInWorkerIsolate({
  required String content,
  required int width,
  required int height,
  required int margin,
  required BarcodeEccLevel eccLevel,
}) {
  final ffi.DynamicLibrary? dylib = tryOpenZxingDynamicLibrary();
  if (dylib != null) {
    try {
      final ZxingFfiBindings bindings = ZxingFfiBindings(dylib);
      final ffi.Pointer<Utf8> contentPtr = content.toNativeUtf8(
        allocator: calloc,
      );
      ffi.Pointer<CEncodedBarcodeImage> encodedPtr = ffi.nullptr;
      try {
        encodedPtr = bindings.zxing_encode_barcode(
          contentPtr.cast<ffi.Char>(),
          width,
          height,
          margin,
          eccLevel.cValue,
        );
        if (encodedPtr != ffi.nullptr) {
          final CEncodedBarcodeImage img = encodedPtr.ref;
          if (img.rgba_bytes != ffi.nullptr && img.byte_length > 0) {
            return Uint8List.fromList(
              img.rgba_bytes.asTypedList(img.byte_length),
            );
          }
        }
      } finally {
        if (encodedPtr != ffi.nullptr) {
          bindings.free_encoded_barcode_image(encodedPtr);
        }
        calloc.free(contentPtr);
      }
    } catch (_) {
      // Fall through to deterministic fallback barcode matrix generator.
    }
  }

  return BarcodeMatrixCodec.generateFallbackRgbaBarcode(
    content,
    width: width,
    height: height,
    margin: margin,
  );
}
