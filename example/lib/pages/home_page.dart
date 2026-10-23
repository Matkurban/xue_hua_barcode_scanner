import 'dart:typed_data';
import 'package:material_ui/material_ui.dart';
import 'package:xue_hua_barcode_scanner/xue_hua_barcode_scanner.dart';

import '../widgets/barcode_result_tile.dart';
import '../widgets/scan_result_dialog.dart';
import '../widgets/section_card.dart';
import 'custom_scanner_page.dart';
import 'default_scanner_page.dart';

/// 示例应用主页。
class ExampleHomePage extends StatefulWidget {
  const ExampleHomePage({super.key});

  @override
  State<ExampleHomePage> createState() => _ExampleHomePageState();
}

class _ExampleHomePageState extends State<ExampleHomePage> {
  late final TextEditingController _barcodeInputController;

  BarcodeEccLevel _selectedEcc = BarcodeEccLevel.medium;
  int _selectedMargin = 2;
  Uint8List? _generatedPngBytes;
  List<BarcodeResult> _latestResults = const <BarcodeResult>[];
  String _statusLog = '准备就绪：点击下方按钮打开扫码页，或直接生成并验证条码/二维码。';
  bool _isWorking = false;

  @override
  void initState() {
    super.initState();
    _barcodeInputController = TextEditingController(
      text: 'https://github.com/Matkurban/xue_hua_barcode_scanner',
    );
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
                '支持全屏相机预览、镂空圆角扫描框、绿色平滑扫描线、“将二维码放入框内”提示、前后摄切换、手电筒与相册选图识别。',
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
          const SizedBox(height: 16),
          ExampleSectionCard(
            icon: Icons.qr_code_2_rounded,
            title: '2. 静态图片解码与条码生成实验室 (zxing-cpp)',
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
                      child: DropdownButtonFormField<BarcodeEccLevel>(
                        initialValue: _selectedEcc,
                        decoration: const InputDecoration(
                          labelText: '纠错等级 (ECC)',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: BarcodeEccLevel.values
                            .map(
                              (BarcodeEccLevel level) =>
                                  DropdownMenuItem<BarcodeEccLevel>(
                                value: level,
                                child: Text(level.name.toUpperCase()),
                              ),
                            )
                            .toList(),
                        onChanged: (BarcodeEccLevel? value) {
                          if (value != null) {
                            setState(() => _selectedEcc = value);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        initialValue: _selectedMargin,
                        decoration: const InputDecoration(
                          labelText: '边距 (Margin)',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: const <int>[1, 2, 4, 6]
                            .map(
                              (int m) => DropdownMenuItem<int>(
                                value: m,
                                child: Text('$m modules'),
                              ),
                            )
                            .toList(),
                        onChanged: (int? value) {
                          if (value != null) {
                            setState(() => _selectedMargin = value);
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
                      label: const Text('生成条码并立即解码验证'),
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
                if (_generatedPngBytes != null) ...<Widget>[
                  const SizedBox(height: 16),
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Image.memory(
                        _generatedPngBytes!,
                        width: 200,
                        height: 200,
                        fit: BoxFit.contain,
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
                  const Text(
                    '暂无解码记录',
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

  /// 生成条码 PNG 并立即通过 `decodeImageMemory` 解码校验。
  Future<void> _generateAndDecodeSample() async {
    final String content = _barcodeInputController.text.trim();
    if (content.isEmpty) return;

    setState(() {
      _isWorking = true;
    });

    try {
      final Uint8List pngBytes = await XueHuaBarcodeScanner.encodeBarcode(
        content,
        width: 420,
        height: 420,
        margin: _selectedMargin,
        eccLevel: _selectedEcc,
      );
      final List<BarcodeResult> decoded =
          await XueHuaBarcodeScanner.decodeImageMemory(pngBytes);

      if (!mounted) return;
      setState(() {
        _generatedPngBytes = pngBytes;
        _latestResults = decoded;
        _statusLog = decoded.isNotEmpty
            ? '编码并解码验证成功: "${decoded.first.text}" (${decoded.first.format.displayName})'
            : '条码图片已生成 (${pngBytes.lengthInBytes} bytes)';
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
    setState(() => _isWorking = true);
    try {
      const int width = 264;
      const int height = 264;
      const int rowStride = 288;
      final Uint8List png = await XueHuaBarcodeScanner.encodeBarcode(
        _barcodeInputController.text.trim(),
        width: width,
        height: height,
        margin: _selectedMargin,
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
      final Uint8List? imageBytes =
          await XueHuaBarcodeScanner.engine.pickImageFromGallery();
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
    final List<BarcodeResult>? results =
        await Navigator.of(context).push<List<BarcodeResult>>(
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

  /// 打开自定义 UI 样式的扫码页面。
  Future<void> _openCustomScannerPage() async {
    final List<BarcodeResult>? results =
        await Navigator.of(context).push<List<BarcodeResult>>(
      MaterialPageRoute<List<BarcodeResult>>(
        builder: (BuildContext context) => const CustomStyledScannerDemoPage(),
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
