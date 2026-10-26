import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';
import 'package:xue_hua_barcode_scanner/xue_hua_barcode_scanner.dart';
import 'package:xue_hua_qr_code/xue_hua_qr_code.dart';

import '../widgets/barcode_result_tile.dart';
import '../widgets/scan_result_dialog.dart';
import '../widgets/section_card.dart';
import 'custom_scanner_page.dart';
import 'default_scanner_page.dart';
import 'input_source_menu_demo_page.dart';

/// 示例应用主页。
class ExampleHomePage extends StatefulWidget {
  const ExampleHomePage({super.key});

  @override
  State<ExampleHomePage> createState() => _ExampleHomePageState();
}

class _ExampleHomePageState extends State<ExampleHomePage> {
  late final TextEditingController _barcodeInputController;

  QrErrorLevel _selectedEcc = QrErrorLevel.medium;
  QrModuleShape _selectedShape = QrModuleShape.square;
  String _currentQrValue =
      'https://github.com/Matkurban/xue_hua_barcode_scanner';
  List<BarcodeResult> _latestResults = const <BarcodeResult>[];
  String _statusLog = '准备就绪：点击下方按钮打开扫码页，或直接生成并验证二维码。';
  bool _isWorking = false;
  int _statusGeneration = 0;

  @override
  void initState() {
    super.initState();
    _barcodeInputController = TextEditingController(text: _currentQrValue);
    _generateAndDecodeSample();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const ValueKey<String>('xh_home_page'),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Text('XueHua Barcode Scanner (v1.0.0)'),
            Text(
              'Engine: ${XueHuaBarcodeScanner.engineVersion}',
              key: const ValueKey<String>('xh_engine_version'),
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
      ),
      body: ListView(
        key: const ValueKey<String>('xh_home_list'),
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          if (_isWorking)
            const SizedBox.shrink(key: ValueKey<String>('xh_home_busy')),
          ExampleSectionCard(
            icon: Icons.qr_code_scanner_rounded,
            title: '1. 实时相机条码/二维码扫描页面 (6 端统一组件)',
            subtitle:
                '进入扫码页即使用平台默认相机，不会弹出设备菜单。'
                '多个输入源时，点击右上角按钮用菜单选择；只有一个输入源时不显示该按钮。',
            child: Row(
              children: <Widget>[
                Expanded(
                  child: FilledButton.icon(
                    key: const ValueKey<String>('xh_open_default_scanner'),
                    onPressed: _openDefaultScannerPage,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF00E676),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    icon: const Icon(Icons.qr_code_scanner_rounded),
                    label: const Text('打开标准默认扫码页'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    key: const ValueKey<String>('xh_open_custom_scanner'),
                    onPressed: _openCustomScannerPage,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    icon: const Icon(Icons.auto_awesome_rounded),
                    label: const Text('打开深度自定义扫码页'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            key: const ValueKey<String>('xh_open_input_source_demo'),
            onPressed: _openInputSourceDemo,
            icon: const Icon(Icons.cameraswitch_rounded),
            label: const Text('查看多输入源 / 单输入源选择'),
          ),
          const SizedBox(height: 16),
          ExampleSectionCard(
            icon: Icons.qr_code_2_rounded,
            title: '2. 二维码生成 (xue_hua_qr_code) 与静态解码实验室 (zxing-cpp)',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                TextField(
                  key: const ValueKey<String>('xh_barcode_input'),
                  controller: _barcodeInputController,
                  decoration: InputDecoration(
                    labelText: '输入要编码的文本或 URL',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    suffixIcon: IconButton(
                      key: const ValueKey<String>('xh_barcode_input_clear'),
                      tooltip: '清空',
                      icon: const Icon(Icons.clear),
                      onPressed: _barcodeInputController.clear,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: DropdownButtonFormField<QrErrorLevel>(
                        key: const ValueKey<String>('xh_ecc_dropdown'),
                        initialValue: _selectedEcc,
                        decoration: const InputDecoration(
                          labelText: '纠错等级 (ECC)',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: QrErrorLevel.values
                            .map(
                              (QrErrorLevel level) =>
                                  DropdownMenuItem<QrErrorLevel>(
                                    value: level,
                                    child: Text(level.name.toUpperCase()),
                                  ),
                            )
                            .toList(),
                        onChanged: (QrErrorLevel? value) {
                          if (value != null) {
                            setState(() => _selectedEcc = value);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<QrModuleShape>(
                        key: const ValueKey<String>('xh_shape_dropdown'),
                        initialValue: _selectedShape,
                        decoration: const InputDecoration(
                          labelText: '码点样式 (Shape)',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: QrModuleShape.values
                            .map(
                              (QrModuleShape shape) =>
                                  DropdownMenuItem<QrModuleShape>(
                                    value: shape,
                                    child: Text(shape.name),
                                  ),
                            )
                            .toList(),
                        onChanged: (QrModuleShape? value) {
                          if (value != null) {
                            setState(() => _selectedShape = value);
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: <Widget>[
                    FilledButton.tonalIcon(
                      key: const ValueKey<String>('xh_generate_and_decode'),
                      onPressed: _isWorking ? null : _generateAndDecodeSample,
                      icon: const Icon(Icons.qr_code_2_rounded),
                      label: const Text('生成二维码并立即解码验证'),
                    ),
                    OutlinedButton.icon(
                      key: const ValueKey<String>('xh_pick_gallery'),
                      onPressed: _isWorking ? null : _pickAndDecodeFromGallery,
                      icon: const Icon(Icons.photo_library_outlined),
                      label: const Text('从相册选图解码'),
                    ),
                    OutlinedButton.icon(
                      key: const ValueKey<String>('xh_row_stride_decode'),
                      onPressed: _isWorking ? null : _testRowStrideYPlaneDecode,
                      icon: const Icon(Icons.memory_rounded),
                      label: const Text('验证 YUV rowStride 对齐解码'),
                    ),
                  ],
                ),
                if (_currentQrValue.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 16),
                  Center(
                    child: Container(
                      key: const ValueKey<String>('xh_qr_preview'),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: XueHuaQrCode(
                        value: _currentQrValue,
                        size: 200,
                        errorCorrectionLevel: _selectedEcc,
                        style: QrStyle(
                          shape: _selectedShape,
                          padding: const EdgeInsets.all(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          ExampleSectionCard(
            icon: Icons.verified_rounded,
            title: '3. 解码结果与定位角点 (BarcodeResult)',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  _statusLog,
                  key: const ValueKey<String>('xh_status_log'),
                  style: const TextStyle(
                    color: Color(0xFF69F0AE),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 8),
                if (_latestResults.isEmpty)
                  const Text(
                    '暂无解码记录',
                    key: ValueKey<String>('xh_empty_results'),
                    style: TextStyle(color: Colors.white54),
                  )
                else
                  for (final BarcodeResult item in _latestResults)
                    BarcodeResultTile(result: item),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 使用 `xue_hua_qr_code` 生成二维码 PNG 并立即通过 `decodeImageMemory` 解码校验。
  Future<void> _generateAndDecodeSample() async {
    final String content = _barcodeInputController.text.trim();
    if (content.isEmpty) return;

    final int op = _beginStatusOp(currentValue: content);
    try {
      final _VerificationImage spec = _verificationImage(content);
      final Uint8List pngBytes = await XueHuaQrCode.toPngBytes(
        content,
        size: spec.size,
        errorCorrectionLevel: _selectedEcc,
        style: spec.style,
      );
      final List<BarcodeResult> decoded =
          await XueHuaBarcodeScanner.decodeImageMemory(pngBytes);

      if (!mounted || op != _statusGeneration) return;
      final String outcome = decoded.isNotEmpty
          ? '解码验证成功: "${decoded.first.text}" '
                '(${decoded.first.format.displayName})'
          : '未识别到条码 (${pngBytes.lengthInBytes} bytes)';
      _finishStatusOp(op, outcome, results: decoded);
    } catch (e) {
      _finishStatusOp(op, '操作异常: $e');
    }
  }

  /// 把生成的二维码展开成带行填充的 Y 平面，再走 `decodeImageBytes` 的 rowStride 路径。
  Future<void> _testRowStrideYPlaneDecode() async {
    final String content = _barcodeInputController.text.trim();
    if (content.isEmpty) return;

    final int op = _beginStatusOp(currentValue: content);
    try {
      final _VerificationImage spec = _verificationImage(content);
      final Uint8List png = await XueHuaQrCode.toPngBytes(
        content,
        size: spec.size,
        errorCorrectionLevel: _selectedEcc,
        style: spec.style,
      );
      final _LumaPlane plane = await _pngToPaddedLuma(png);
      final List<BarcodeResult> decoded =
          await XueHuaBarcodeScanner.decodeImageBytes(
            plane.bytes,
            width: plane.width,
            height: plane.height,
            rowStride: plane.rowStride,
            format: PixelFormat.lum,
          );
      if (!mounted || op != _statusGeneration) return;
      final String texts = decoded.map((BarcodeResult e) => e.text).join(", ");
      final String outcome = decoded.isNotEmpty
          ? 'Y-Plane (rowStride=${plane.rowStride}, width=${plane.width}) '
                '内存对齐解码成功: $texts'
          : 'Y-Plane (rowStride=${plane.rowStride}, width=${plane.width}) '
                '未识别到条码';
      _finishStatusOp(op, outcome, results: decoded);
    } catch (e) {
      _finishStatusOp(op, '操作异常: $e');
    }
  }

  /// 开始一轮可等待的状态。结束时状态行一定包含 `phase=done` 和本次编号。
  int _beginStatusOp({String? currentValue}) {
    final int op = ++_statusGeneration;
    setState(() {
      _isWorking = true;
      if (currentValue != null) {
        _currentQrValue = currentValue;
      }
      _statusLog = 'op=$op phase=running';
    });
    return op;
  }

  void _finishStatusOp(int op, String outcome, {List<BarcodeResult>? results}) {
    if (!mounted || op != _statusGeneration) return;
    setState(() {
      _isWorking = false;
      if (results != null) {
        _latestResults = results;
      }
      _statusLog =
          'op=$op phase=done ecc=${_selectedEcc.name} '
          'shape=${_selectedShape.name} $outcome';
    });
  }

  /// 整像素模块边长，避免圆形/圆角码点落在小数像素上时 zxing 时而识别失败。
  _VerificationImage _verificationImage(String content) {
    final QrMatrix matrix = QrMatrix.encode(content, errorLevel: _selectedEcc);
    final int modulePx = _selectedShape == QrModuleShape.square ? 10 : 16;
    const int quietModules = 4;
    final double quiet = quietModules * modulePx.toDouble();
    return _VerificationImage(
      size: (matrix.moduleCount + quietModules * 2) * modulePx.toDouble(),
      style: QrStyle(
        shape: _selectedShape,
        padding: EdgeInsets.all(quiet),
        moduleGap: 0,
      ),
    );
  }

  /// 从系统相册/文件选择器选取真实图片并解码。
  Future<void> _pickAndDecodeFromGallery() async {
    final int op = _beginStatusOp();
    try {
      final Uint8List? imageBytes = await XueHuaBarcodeScanner.engine
          .pickImageFromGallery();
      if (imageBytes == null || imageBytes.isEmpty) {
        _finishStatusOp(op, '已取消选择图片');
        return;
      }
      final List<BarcodeResult> decoded =
          await XueHuaBarcodeScanner.decodeImageMemory(imageBytes);
      if (!mounted || op != _statusGeneration) return;
      final String outcome = decoded.isNotEmpty
          ? '【相册图片识别成功】共 ${decoded.length} 个条码: ${decoded.first.text}'
          : '所选图片中未识别到有效条码或二维码';
      _finishStatusOp(op, outcome, results: decoded);
      if (decoded.isNotEmpty) {
        await ScanResultDialog.show(
          context,
          title: '相册图片 · 识别结果',
          results: decoded,
        );
      }
    } catch (e) {
      _finishStatusOp(op, '操作异常: $e');
    }
  }

  /// 打开默认配置的扫码页面。
  Future<void> _openDefaultScannerPage() async {
    final List<BarcodeResult>? results = await Navigator.of(context)
        .push<List<BarcodeResult>>(
          MaterialPageRoute<List<BarcodeResult>>(
            builder: (BuildContext context) => const DefaultScannerDemoPage(),
          ),
        );
    if (results != null && results.isNotEmpty && mounted) {
      setState(() {
        _latestResults = results;
        _statusLog = '【标准默认扫码页】识别成功: ${results.first.text}';
      });
    }
  }

  /// 打开不启动相机的输入源菜单演示。
  Future<void> _openInputSourceDemo() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => const InputSourceMenuDemoPage(),
      ),
    );
  }

  /// 打开自定义 UI 样式的扫码页面。
  Future<void> _openCustomScannerPage() async {
    final List<BarcodeResult>? results = await Navigator.of(context)
        .push<List<BarcodeResult>>(
          MaterialPageRoute<List<BarcodeResult>>(
            builder: (BuildContext context) =>
                const CustomStyledScannerDemoPage(),
          ),
        );
    if (results != null && results.isNotEmpty && mounted) {
      setState(() {
        _latestResults = results;
        _statusLog = '【自定义 UI 扫码页】识别成功: ${results.first.text}';
      });
    }
  }

  @override
  void dispose() {
    _barcodeInputController.dispose();
    super.dispose();
  }
}

class _VerificationImage {
  const _VerificationImage({required this.size, required this.style});

  final double size;
  final QrStyle style;
}

class _LumaPlane {
  const _LumaPlane({
    required this.bytes,
    required this.width,
    required this.height,
    required this.rowStride,
  });

  final Uint8List bytes;
  final int width;
  final int height;
  final int rowStride;
}

/// Decodes [png] and copies luminance into a buffer whose rows are padded.
///
/// Padding stays past `width` so a decoder that ignores `rowStride` reads the
/// wrong pixels. The stride is always greater than [width].
Future<_LumaPlane> _pngToPaddedLuma(Uint8List png) async {
  final ui.Codec codec = await ui.instantiateImageCodec(png);
  try {
    final ui.FrameInfo frame = await codec.getNextFrame();
    final ui.Image image = frame.image;
    try {
      final ByteData? raw = await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );
      if (raw == null || image.width <= 0 || image.height <= 0) {
        throw StateError('无法把二维码展开成像素');
      }
      final int width = image.width;
      final int height = image.height;
      final int rowStride = width + 32;
      final Uint8List yPlane = Uint8List(rowStride * height);
      final Uint8List rgba = raw.buffer.asUint8List();
      for (int y = 0; y < height; y++) {
        final int srcRow = y * width * 4;
        final int dstRow = y * rowStride;
        for (int x = 0; x < width; x++) {
          final int i = srcRow + x * 4;
          final int luma = (rgba[i] + rgba[i + 1] + rgba[i + 2]) ~/ 3;
          yPlane[dstRow + x] = luma < 128 ? 0 : 255;
        }
      }
      return _LumaPlane(
        bytes: yPlane,
        width: width,
        height: height,
        rowStride: rowStride,
      );
    } finally {
      image.dispose();
    }
  } finally {
    codec.dispose();
  }
}
