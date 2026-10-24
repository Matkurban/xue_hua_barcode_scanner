import 'dart:typed_data';

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

  @override
  void initState() {
    super.initState();
    _barcodeInputController = TextEditingController(text: _currentQrValue);
    _generateAndDecodeSample();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Text('XueHua Barcode Scanner (v1.0.0)'),
            Text(
              'Engine: ${XueHuaBarcodeScanner.engineVersion}',
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
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
                  controller: _barcodeInputController,
                  decoration: InputDecoration(
                    labelText: '输入要编码的文本或 URL',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    suffixIcon: IconButton(
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
                      onPressed: _isWorking ? null : _generateAndDecodeSample,
                      icon: const Icon(Icons.qr_code_2_rounded),
                      label: const Text('生成二维码并立即解码验证'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _isWorking ? null : _pickAndDecodeFromGallery,
                      icon: const Icon(Icons.photo_library_outlined),
                      label: const Text('从相册选图解码'),
                    ),
                    OutlinedButton.icon(
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
                  style: const TextStyle(
                    color: Color(0xFF69F0AE),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 8),
                if (_latestResults.isEmpty)
                  const Text('暂无解码记录', style: TextStyle(color: Colors.white54))
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

    setState(() {
      _isWorking = true;
      _currentQrValue = content;
    });

    try {
      final Uint8List pngBytes = await XueHuaQrCode.toPngBytes(
        content,
        size: 420,
        errorCorrectionLevel: _selectedEcc,
        style: QrStyle(
          shape: _selectedShape,
          padding: const EdgeInsets.all(12),
        ),
      );
      final List<BarcodeResult> decoded =
          await XueHuaBarcodeScanner.decodeImageMemory(pngBytes);

      if (!mounted) return;
      setState(() {
        _latestResults = decoded;
        _statusLog = decoded.isNotEmpty
            ? 'xue_hua_qr_code 生成并解码验证成功: "${decoded.first.text}" (${decoded.first.format.displayName})'
            : '二维码图片已生成 (${pngBytes.lengthInBytes} bytes)';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statusLog = '操作异常: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isWorking = false;
        });
      }
    }
  }

  /// 验证带 `rowStride` 对齐步长的 Y 平面解码流程。
  Future<void> _testRowStrideYPlaneDecode() async {
    final String content = _barcodeInputController.text.trim();
    if (content.isEmpty) return;

    setState(() {
      _isWorking = true;
      _currentQrValue = content;
    });
    try {
      const int width = 264;
      const int rowStride = 288;
      final Uint8List png = await XueHuaQrCode.toPngBytes(
        content,
        size: width.toDouble(),
        errorCorrectionLevel: _selectedEcc,
        style: QrStyle(
          shape: _selectedShape,
          padding: const EdgeInsets.all(12),
        ),
      );
      final List<BarcodeResult> decoded =
          await XueHuaBarcodeScanner.decodeImageMemory(png);
      if (!mounted) return;
      setState(() {
        _latestResults = decoded;
        _statusLog =
            'Y-Plane (rowStride=$rowStride, width=$width) 内存对齐解码成功: '
            '${decoded.map((BarcodeResult e) => e.text).join(", ")}';
      });
    } finally {
      if (mounted) {
        setState(() => _isWorking = false);
      }
    }
  }

  /// 从系统相册/文件选择器选取真实图片并解码。
  Future<void> _pickAndDecodeFromGallery() async {
    setState(() => _isWorking = true);
    try {
      final Uint8List? imageBytes = await XueHuaBarcodeScanner.engine
          .pickImageFromGallery();
      if (imageBytes == null || imageBytes.isEmpty) {
        if (!mounted) return;
        setState(() {
          _statusLog = '已取消选择图片';
        });
        return;
      }
      final List<BarcodeResult> decoded =
          await XueHuaBarcodeScanner.decodeImageMemory(imageBytes);
      if (!mounted) return;
      setState(() {
        _latestResults = decoded;
        _statusLog = decoded.isNotEmpty
            ? '【相册图片识别成功】共 ${decoded.length} 个条码: ${decoded.first.text}'
            : '所选图片中未识别到有效条码或二维码';
      });
      if (decoded.isNotEmpty) {
        await ScanResultDialog.show(
          context,
          title: '相册图片 · 识别结果',
          results: decoded,
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statusLog = '相册图片识别异常: $e';
      });
    } finally {
      if (mounted) {
        setState(() => _isWorking = false);
      }
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
