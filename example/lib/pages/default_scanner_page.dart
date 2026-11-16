import 'dart:convert';
import 'dart:typed_data';

import 'package:material_ui/material_ui.dart';
import 'package:xue_hua_barcode_scanner/xue_hua_barcode_scanner.dart';

import '../widgets/scan_result_dialog.dart';

/// 微信扫一扫风格默认扫码演示页面：
/// - 默认采用全屏无挖孔沉浸式取景 + 微信绿渐变网格光幕扫描线；
/// - 当画面识别到 2 个及以上二维码时，自动冻结画面并在各二维码位置展示带呼吸光圈与白色箭头的小绿点，
///   由用户点击对应小绿点完成精准选择；
/// - 顶部提供「模拟双码同屏点选」快捷演示按钮，方便在无双码实物时一键体验多码暂停点选交互。
class DefaultScannerDemoPage extends StatefulWidget {
  const DefaultScannerDemoPage({super.key});

  @override
  State<DefaultScannerDemoPage> createState() => _DefaultScannerDemoPageState();
}

class _DefaultScannerDemoPageState extends State<DefaultScannerDemoPage> {
  late final XueHuaScannerController _controller;
  bool _isShowingDialog = false;

  @override
  void initState() {
    super.initState();
    _controller = XueHuaScannerController(
      initialFacing: CameraFacing.back,
      autoPauseOnDetect: true,
      enableMultiBarcodeSelection: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          XueHuaBarcodeScannerPage(
            key: const ValueKey<String>('xh_default_scanner_page'),
            controller: _controller,
            autoPopOnDetect: false,
            texts: const XueHuaScannerTexts(
              hintText: '扫二维码 / 条码',
              multiBarcodeHintText: '轻触小绿点，选择要识别的码',
              cancelMultiSelectLabel: '取消',
              invalidBarcodeText: '二维码不符合要求',
              noBarcodeInImageText: '未在所选图片中识别到二维码或条码',
              torchOnLabel: '轻触关闭',
              torchOffLabel: '轻触照亮',
              galleryLabel: '相册',
            ),
            onDetect: _handleBarcodeDetected,
          ),
          SafeArea(
            child: ValueListenableBuilder<ScannerState>(
              valueListenable: _controller,
              builder: (BuildContext context, ScannerState state, Widget? _) {
                if (state.isSelectingMultiBarcode) {
                  return const SizedBox.shrink();
                }
                return Align(
                  alignment: Alignment.topCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: FilledButton.tonalIcon(
                      key: const ValueKey<String>(
                        'xh_simulate_multi_barcode_button',
                      ),
                      onPressed: _simulateMultiBarcodes,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xCC07C160),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                      icon: const Icon(Icons.qr_code_2_rounded, size: 17),
                      label: const Text(
                        '模拟双码同屏点选',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _simulateMultiBarcodes() async {
    const Size demoFrameSize = Size(390, 844);
    final List<BarcodeResult> simulated = <BarcodeResult>[
      BarcodeResult(
        text: 'XH-WECHAT-QR-A1024',
        rawBytes: Uint8List.fromList(utf8.encode('XH-WECHAT-QR-A1024')),
        cornerPoints: const <Offset>[
          Offset(65, 240),
          Offset(165, 240),
          Offset(165, 340),
          Offset(65, 340),
        ],
        format: BarcodeFormat.qrCode,
        frameSize: demoFrameSize,
      ),
      BarcodeResult(
        text: 'XH-WECHAT-QR-B2048',
        rawBytes: Uint8List.fromList(utf8.encode('XH-WECHAT-QR-B2048')),
        cornerPoints: const <Offset>[
          Offset(225, 420),
          Offset(325, 420),
          Offset(325, 520),
          Offset(225, 520),
        ],
        format: BarcodeFormat.qrCode,
        frameSize: demoFrameSize,
      ),
    ];
    await _controller.simulateMultiBarcodeDetection(simulated);
  }

  /// 处理扫码识别结果并弹出详情对话框。
  Future<void> _handleBarcodeDetected(List<BarcodeResult> results) async {
    if (_isShowingDialog || results.isEmpty || !mounted) {
      return;
    }
    _isShowingDialog = true;
    await _controller.pause();
    if (!mounted) {
      _isShowingDialog = false;
      return;
    }

    final bool? shouldReturn = await ScanResultDialog.show(
      context,
      title: '微信风格扫码页 · 识别结果',
      results: results,
    );
    _isShowingDialog = false;

    if (!mounted) return;
    if (shouldReturn == true) {
      Navigator.of(context).maybePop(results);
    } else {
      await _controller.resume();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
