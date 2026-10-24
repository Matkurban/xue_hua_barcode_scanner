import 'package:material_ui/material_ui.dart';
import 'package:xue_hua_barcode_scanner/xue_hua_barcode_scanner.dart';

import '../widgets/scan_result_dialog.dart';

/// 标准默认扫码演示页面，识别到条码后弹出 [ScanResultDialog] 展示结果。
///
/// 进入页面后直接使用平台默认相机，不弹出输入源菜单。多个输入源时，顶栏按钮
/// 由用户点击后通过 `chat_context_menu` 选择设备；只有一个输入源时不显示该按钮。
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return XueHuaBarcodeScannerPage(
      controller: _controller,
      autoPopOnDetect: false,
      texts: const XueHuaScannerTexts(
        hintText: '将二维码放入框内',
        invalidBarcodeText: '二维码不符合要求',
        noBarcodeInImageText: '未在所选图片中识别到二维码或条码',
        torchOnLabel: '轻触关闭',
        torchOffLabel: '手电筒',
        galleryLabel: '相册',
      ),
      onDetect: _handleBarcodeDetected,
    );
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
      title: '标准扫码页 · 识别结果',
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
