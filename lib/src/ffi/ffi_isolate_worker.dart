import 'dart:async';
import 'dart:convert';
import 'dart:ffi' as ffi;
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'dart:ui' show Offset, Size;

import 'package:ffi/ffi.dart';

import '../core/barcode_matrix_codec.dart';
import '../models/barcode_enums.dart';
import '../models/barcode_result.dart';
import 'row_stride_normalizer.dart';
import 'zxing_ffi_bindings.dart';

const String _kLibName = 'xue_hua_barcode_scanner';

const List<String> _kLinuxLibraryNames = <String>[
  'lib$_kLibName.so',
  'lib$_kLibName.so.1',
  'lib$_kLibName.so.1.0.0',
];

/// Opens the zxing FFI library on Android or Linux.
///
/// The unversioned soname is tried first. Linux CMake builds that set
/// VERSION/SOVERSION only ship the real file (`*.so.1.0.0`) next to the
/// executable, so those names and `$ORIGIN/lib` are tried as well.
ffi.DynamicLibrary? _openAndroidOrLinuxLibrary() {
  for (final String name in _kLinuxLibraryNames) {
    final ffi.DynamicLibrary? opened = _tryOpenLibrary(name);
    if (opened != null) {
      return opened;
    }
  }

  final String executableDir = File(Platform.resolvedExecutable).parent.path;
  final List<String> directories = <String>[
    executableDir,
    '$executableDir${Platform.pathSeparator}lib',
  ];
  for (final String directory in directories) {
    for (final String name in _kLinuxLibraryNames) {
      final String path = '$directory${Platform.pathSeparator}$name';
      if (!File(path).existsSync()) {
        continue;
      }
      final ffi.DynamicLibrary? opened = _tryOpenLibrary(path);
      if (opened != null) {
        return opened;
      }
    }
  }
  return null;
}

/// Opens the zxing FFI library on Windows.
///
/// The bare DLL name is tried first (the exe directory is on the Windows
/// search path). A full path next to the executable covers worker isolates
/// whose search path does not include that directory.
ffi.DynamicLibrary? _openWindowsLibrary() {
  final ffi.DynamicLibrary? byName = _tryOpenLibrary('$_kLibName.dll');
  if (byName != null) {
    return byName;
  }
  final String executableDir = File(Platform.resolvedExecutable).parent.path;
  final String path = '$executableDir${Platform.pathSeparator}$_kLibName.dll';
  if (!File(path).existsSync()) {
    return null;
  }
  return _tryOpenLibrary(path);
}

ffi.DynamicLibrary? _tryOpenLibrary(String path) {
  try {
    final ffi.DynamicLibrary library = ffi.DynamicLibrary.open(path);
    if (library.providesSymbol('zxing_decode_image_bytes')) {
      return library;
    }
  } catch (_) {}
  return null;
}

ZxingFfiBindings? _cachedBindings;
bool _didProbeDynamicLibrary = false;
ffi.Pointer<ffi.Uint8> _reusableBuffer = ffi.nullptr;
int _reusableBufferCapacity = 0;

ZxingFfiBindings? _getCachedZxingBindings() {
  if (_cachedBindings != null) {
    return _cachedBindings;
  }
  if (_didProbeDynamicLibrary) {
    return null;
  }
  _didProbeDynamicLibrary = true;
  final ffi.DynamicLibrary? dylib = tryOpenZxingDynamicLibrary();
  if (dylib != null) {
    _cachedBindings = ZxingFfiBindings(dylib);
  }
  return _cachedBindings;
}

ffi.Pointer<ffi.Uint8> _acquireReusableNativeBuffer(int length) {
  if (_reusableBufferCapacity < length || _reusableBuffer == ffi.nullptr) {
    if (_reusableBuffer != ffi.nullptr) {
      calloc.free(_reusableBuffer);
      _reusableBuffer = ffi.nullptr;
      _reusableBufferCapacity = 0;
    }
    _reusableBuffer = calloc<ffi.Uint8>(length);
    _reusableBufferCapacity = length;
  }
  return _reusableBuffer;
}

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
      return _openAndroidOrLinuxLibrary();
    }
    if (Platform.isWindows) {
      return _openWindowsLibrary();
    }
  } catch (_) {
    return null;
  }
  return null;
}

/// Reads the underlying native engine version string via FFI.
String readNativeEngineVersion() {
  final ZxingFfiBindings? bindings = _getCachedZxingBindings();
  if (bindings != null) {
    try {
      final ffi.Pointer<ffi.Char> ptr = bindings.zxing_engine_version();
      if (ptr != ffi.nullptr) {
        return ptr.cast<Utf8>().toDartString();
      }
    } catch (_) {}
  }
  return 'zxing-cpp 3.1.1 (FFI Isolate Worker)';
}

/// Persistent background worker Isolate that eliminates per-frame Isolate
/// creation/teardown overhead and uses zero-copy [TransferableTypedData]
/// to prevent UI isolate frame drops.
class _PersistentZxingWorker {
  _PersistentZxingWorker._();

  static final _PersistentZxingWorker instance = _PersistentZxingWorker._();

  Isolate? _isolate;
  SendPort? _commandPort;
  Future<bool>? _initializing;
  int _nextTaskId = 0;
  final Map<int, Completer<List<BarcodeResult>>> _pending =
      <int, Completer<List<BarcodeResult>>>{};

  Future<bool> _ensureStarted() {
    if (_commandPort != null && _isolate != null) {
      return Future<bool>.value(true);
    }
    if (_initializing != null) {
      return _initializing!;
    }
    final Completer<bool> completer = Completer<bool>();
    _initializing = completer.future;

    final ReceivePort receivePort = ReceivePort();

    receivePort.listen((dynamic message) {
      if (message is SendPort) {
        _commandPort = message;
        if (!completer.isCompleted) {
          completer.complete(true);
        }
        return;
      }
      if (message is Map<String, Object?>) {
        final int? id = message['id'] as int?;
        if (id == null) return;
        final Completer<List<BarcodeResult>>? task = _pending.remove(id);
        if (task == null || task.isCompleted) return;
        final List<BarcodeResult>? results =
            message['results'] as List<BarcodeResult>?;
        task.complete(results ?? const <BarcodeResult>[]);
      }
    });

    Isolate.spawn<SendPort>(
      _persistentWorkerEntryPoint,
      receivePort.sendPort,
      debugName: 'XueHuaZxingPersistentWorker',
    ).then((Isolate spawned) {
      _isolate = spawned;
    }).catchError((Object _) {
      receivePort.close();
      _initializing = null;
      if (!completer.isCompleted) {
        completer.complete(false);
      }
    });

    return completer.future;
  }

  Future<List<BarcodeResult>> decode({
    required Uint8List rawPixelBytes,
    required int width,
    required int height,
    required int rowStride,
    required PixelFormat format,
    required bool tryHarder,
    required bool tryRotate,
    required bool tryInvert,
  }) async {
    final bool ready = await _ensureStarted();
    final SendPort? port = _commandPort;
    if (!ready || port == null) {
      return Isolate.run(
        () => decodeInWorkerIsolate(
          rawPixelBytes: rawPixelBytes,
          width: width,
          height: height,
          rowStride: rowStride,
          format: format,
          tryHarder: tryHarder,
          tryRotate: tryRotate,
          tryInvert: tryInvert,
        ),
      );
    }

    final int taskId = ++_nextTaskId;
    final Completer<List<BarcodeResult>> completer =
        Completer<List<BarcodeResult>>();
    _pending[taskId] = completer;

    final TransferableTypedData transferable = TransferableTypedData.fromList(
      <Uint8List>[rawPixelBytes],
    );
    port.send(<String, Object?>{
      'id': taskId,
      'bytes': transferable,
      'width': width,
      'height': height,
      'rowStride': rowStride,
      'format': format,
      'tryHarder': tryHarder,
      'tryRotate': tryRotate,
      'tryInvert': tryInvert,
    });

    return completer.future;
  }
}

void _persistentWorkerEntryPoint(SendPort hostPort) {
  final ReceivePort commandPort = ReceivePort();
  hostPort.send(commandPort.sendPort);

  commandPort.listen((dynamic message) {
    if (message is! Map<String, Object?>) return;
    final int? id = message['id'] as int?;
    if (id == null) return;
    try {
      final TransferableTypedData? transferable =
          message['bytes'] as TransferableTypedData?;
      if (transferable == null) {
        hostPort.send(<String, Object?>{
          'id': id,
          'results': const <BarcodeResult>[],
        });
        return;
      }
      final Uint8List rawPixelBytes = transferable.materialize().asUint8List();
      final int width = (message['width'] as int?) ?? 0;
      final int height = (message['height'] as int?) ?? 0;
      final int rowStride = (message['rowStride'] as int?) ?? 0;
      final PixelFormat format =
          (message['format'] as PixelFormat?) ?? PixelFormat.rgba8888;
      final bool tryHarder = (message['tryHarder'] as bool?) ?? true;
      final bool tryRotate = (message['tryRotate'] as bool?) ?? true;
      final bool tryInvert = (message['tryInvert'] as bool?) ?? true;

      final List<BarcodeResult> decoded = decodeInWorkerIsolate(
        rawPixelBytes: rawPixelBytes,
        width: width,
        height: height,
        rowStride: rowStride,
        format: format,
        tryHarder: tryHarder,
        tryRotate: tryRotate,
        tryInvert: tryInvert,
      );
      hostPort.send(<String, Object?>{'id': id, 'results': decoded});
    } catch (_) {
      hostPort.send(<String, Object?>{
        'id': id,
        'results': const <BarcodeResult>[],
      });
    }
  });
}

/// Dispatches frame decoding to the persistent zero-copy background worker
/// Isolate, eliminating per-frame Isolate spawn overhead on the UI thread.
Future<List<BarcodeResult>> decodeWithPersistentWorker({
  required Uint8List rawPixelBytes,
  required int width,
  required int height,
  required int rowStride,
  required PixelFormat format,
  required bool tryHarder,
  required bool tryRotate,
  required bool tryInvert,
}) {
  return _PersistentZxingWorker.instance.decode(
    rawPixelBytes: rawPixelBytes,
    width: width,
    height: height,
    rowStride: rowStride,
    format: format,
    tryHarder: tryHarder,
    tryRotate: tryRotate,
    tryInvert: tryInvert,
  );
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
  final ZxingFfiBindings? bindings = _getCachedZxingBindings();
  if (bindings != null) {
    try {
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

      final ffi.Pointer<ffi.Uint8> nativePixels = _acquireReusableNativeBuffer(
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
  final ZxingFfiBindings? bindings = _getCachedZxingBindings();
  if (bindings != null) {
    try {
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
