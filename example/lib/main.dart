import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:xue_hua_barcode_scanner/xue_hua_barcode_scanner.dart';

void main() {
  runApp(const XueHuaBarcodeScannerExampleApp());
}

/// Full-featured demonstration application for `xue_hua_barcode_scanner`.
///
/// Showcases:
/// 1. Standard out-of-the-box `XueHuaBarcodeScannerPage` (green animated scan line,
///    `"将二维码放入框内"` prompt, front/back camera flip, torch, gallery picker,
///    and detected corner-point highlights).
/// 2. Deeply customized scanner UI using `overlayBuilder`, `scanLineBuilder`,
///    `topBarBuilder`, `hintTextBuilder`, `bottomBarBuilder`, `torchButtonBuilder`,
///    and `galleryButtonBuilder` with external `XueHuaScannerController`.
/// 3. Static image barcode encoding (`encodeBarcode`) and decoding (`decodeImageMemory`
///    & `decodeImageBytes` with `PixelFormat.lum` and `rowStride` verification).
class XueHuaBarcodeScannerExampleApp extends StatelessWidget {
  const XueHuaBarcodeScannerExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'XueHua Barcode Scanner Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00C853),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const ExampleHomeScreen(),
    );
  }
}

class ExampleHomeScreen extends StatefulWidget {
  const ExampleHomeScreen({super.key});

  @override
  State<ExampleHomeScreen> createState() => _ExampleHomeScreenState();
}

class _ExampleHomeScreenState extends State<ExampleHomeScreen> {
  final TextEditingController _barcodeInputController = TextEditingController(
    text: 'https://github.com/Matkurban/xue_hua_barcode_scanner',
  );

  BarcodeEccLevel _selectedEcc = BarcodeEccLevel.medium;
  int _selectedMargin = 2;
  Uint8List? _generatedPngBytes;
  List<BarcodeResult> _latestResults = const <BarcodeResult>[];
  String _statusLog = '准备就绪：点击下方按钮打开扫码页，或直接生成并验证条码/二维码。';
  bool _isWorking = false;

  @override
  void initState() {
    super.initState();
    _generateAndDecodeSample();
  }

  @override
  void dispose() {
    _barcodeInputController.dispose();
    super.dispose();
  }

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
            '${decoded.map((e) => e.text).join(", ")}';
      });
    } finally {
      if (mounted) {
        setState(() => _isWorking = false);
      }
    }
  }

  Future<void> _openDefaultScannerPage() async {
    final List<BarcodeResult>? results =
        await Navigator.of(context).push<List<BarcodeResult>>(
      MaterialPageRoute<List<BarcodeResult>>(
        builder: (BuildContext context) => const XueHuaBarcodeScannerPage(
          autoPopOnDetect: true,
          hintText: '将二维码放入框内',
        ),
      ),
    );
    if (results != null && results.isNotEmpty && mounted) {
      setState(() {
        _latestResults = results;
        _statusLog = '【标准默认扫码页】识别成功: ${results.first.text}';
      });
    }
  }

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
          _buildScannerLaunchCards(),
          const SizedBox(height: 16),
          _buildBarcodeGeneratorAndDecoderCard(),
          const SizedBox(height: 16),
          _buildLatestResultCard(),
        ],
      ),
    );
  }

  Widget _buildScannerLaunchCards() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const Text(
              '1. 实时相机条码/二维码扫描页面 (6 端统一组件)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text(
              '支持全屏相机预览、镂空圆角扫描框、绿色平滑扫描线、“将二维码放入框内”提示、前后摄切换、手电筒与相册选图识别。',
              style: TextStyle(fontSize: 13, color: Colors.white70),
            ),
            const SizedBox(height: 14),
            Row(
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
          ],
        ),
      ),
    );
  }

  Widget _buildBarcodeGeneratorAndDecoderCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const Text(
              '2. 静态图片解码与条码生成实验室 (zxing-cpp)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
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
    );
  }

  Widget _buildLatestResultCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              '3. 解码结果与定位角点 (BarcodeResult)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _statusLog,
              style: const TextStyle(color: Color(0xFF69F0AE), fontSize: 13),
            ),
            const SizedBox(height: 8),
            if (_latestResults.isEmpty)
              const Text(
                '暂无解码记录',
                style: TextStyle(color: Colors.white54),
              )
            else
              for (final BarcodeResult r in _latestResults)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: SelectableText(
                    '• 内容: ${r.text}\n'
                    '• 格式: ${r.format.displayName} | 有效: ${r.isValid}\n'
                    '• 中心锚点: (${r.centerPoint.dx.toStringAsFixed(1)}, ${r.centerPoint.dy.toStringAsFixed(1)})\n'
                    '• 4个定位角点: ${r.cornerPoints.map((p) => "(${p.dx.toInt()},${p.dy.toInt()})").join(" -> ")}',
                    style: const TextStyle(fontSize: 12.5, height: 1.5),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

/// Demonstrates 100% custom UI Builders (`overlayBuilder`, `scanLineBuilder`,
/// `topBarBuilder`, `hintTextBuilder`, `torchButtonBuilder`, `galleryButtonBuilder`)
/// paired with an external `XueHuaScannerController`.
class CustomStyledScannerDemoPage extends StatefulWidget {
  const CustomStyledScannerDemoPage({super.key});

  @override
  State<CustomStyledScannerDemoPage> createState() =>
      _CustomStyledScannerDemoPageState();
}

class _CustomStyledScannerDemoPageState
    extends State<CustomStyledScannerDemoPage> {
  late final XueHuaScannerController _controller = XueHuaScannerController(
    initialFacing: CameraFacing.back,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return XueHuaBarcodeScannerPage(
      controller: _controller,
      autoPopOnDetect: true,
      cutoutSize: 270,
      overlayBuilder: (BuildContext context, Rect scanWindow, ScannerState state) {
        return XueHuaScannerOverlay(
          scanWindow: scanWindow,
          maskColor: const Color(0xAA050B14),
          cornerColor: Colors.cyanAccent,
          borderColor: Colors.cyanAccent.withValues(alpha: 0.3),
          borderRadius: 24,
          cornerLength: 32,
          cornerStrokeWidth: 4.5,
        );
      },
      scanLineBuilder: (
        BuildContext context,
        Animation<double> animation,
        Rect scanWindow,
      ) {
        return XueHuaScanLineAnimation(
          animation: animation,
          scanWindow: scanWindow,
          lineColor: Colors.cyanAccent,
          glowHeight: 44,
        );
      },
      hintTextBuilder: (BuildContext context, ScannerState state) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.cyanAccent.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.cyanAccent.withValues(alpha: 0.5)),
          ),
          child: Text(
            state.isPaused ? '已暂停扫描' : '将二维码放入框内 · 自定义赛博主题',
            style: const TextStyle(
              color: Colors.cyanAccent,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        );
      },
      torchButtonBuilder: (
        BuildContext context,
        ScannerState state,
        VoidCallback onToggleTorch,
      ) {
        return FilledButton.tonalIcon(
          onPressed: onToggleTorch,
          icon: Icon(
            state.isTorchOn ? Icons.flashlight_on : Icons.flashlight_off,
            color: state.isTorchOn ? Colors.amberAccent : Colors.cyanAccent,
          ),
          label: Text(state.isTorchOn ? '关闭闪光灯' : '开启闪光灯'),
        );
      },
      galleryButtonBuilder: (
        BuildContext context,
        ScannerState state,
        VoidCallback onPickGallery,
      ) {
        return FilledButton.tonalIcon(
          onPressed: onPickGallery,
          icon: const Icon(Icons.photo_library_outlined, color: Colors.cyanAccent),
          label: const Text('相册导入'),
        );
      },
    );
  }
}
