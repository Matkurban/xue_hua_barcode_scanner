import 'package:material_ui/material_ui.dart';
import 'package:xue_hua_barcode_scanner/xue_hua_barcode_scanner.dart';

import '../widgets/scan_result_dialog.dart';

/// 演示使用自定义 UI Builder、国际化 [XueHuaScannerTexts]、二维码校验 [validator]
/// 与外部 [XueHuaScannerController] 构建的扫码页面。
class CustomStyledScannerDemoPage extends StatefulWidget {
  const CustomStyledScannerDemoPage({super.key});

  @override
  State<CustomStyledScannerDemoPage> createState() =>
      _CustomStyledScannerDemoPageState();
}

class _CustomStyledScannerDemoPageState
    extends State<CustomStyledScannerDemoPage> {
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
    const Color errorColor = Color(0xFFFF5252);
    const Color themeColor = Colors.cyanAccent;

    return XueHuaBarcodeScannerPage(
      controller: _controller,
      autoPopOnDetect: false,
      cutoutSize: 270,
      errorColor: errorColor,
      texts: const XueHuaScannerTexts(
        hintText: '将二维码放入框内 · 自定义赛博主题',
        invalidBarcodeText: '二维码校验未通过',
        noBarcodeInImageText: '所选图片未检测到有效二维码',
        torchOnLabel: '关闭闪光灯',
        torchOffLabel: '开启闪光灯',
        galleryLabel: '相册导入',
      ),
      validator: (BarcodeResult result) {
        return result.isValid && result.text.trim().isNotEmpty;
      },
      onDetect: _handleBarcodeDetected,
      overlayBuilder: (
        BuildContext context,
        Rect scanWindow,
        ScannerState state,
      ) {
        final Color activeColor =
            state.hasValidationError ? errorColor : themeColor;
        return XueHuaScannerOverlay(
          scanWindow: scanWindow,
          maskColor: const Color(0xAA050B14),
          cornerColor: activeColor,
          borderColor: activeColor.withValues(
            alpha: state.hasValidationError ? 0.85 : 0.3,
          ),
          borderStrokeWidth: state.hasValidationError ? 2.2 : 1.2,
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
        return ValueListenableBuilder<ScannerState>(
          valueListenable: _controller,
          builder: (BuildContext context, ScannerState state, Widget? _) {
            return XueHuaScanLineAnimation(
              animation: animation,
              scanWindow: scanWindow,
              lineColor: state.hasValidationError ? errorColor : themeColor,
              glowHeight: 44,
            );
          },
        );
      },
      hintTextBuilder: (BuildContext context, ScannerState state) {
        final bool isError = state.hasValidationError;
        final Color activeColor = isError ? errorColor : themeColor;
        final String text = isError
            ? (state.lastGalleryScanStatus == GalleryScanStatus.noBarcodeFound
                ? '所选图片未检测到有效二维码'
                : '二维码校验未通过')
            : (state.isPaused ? '已暂停扫描' : '将二维码放入框内 · 自定义赛博主题');
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: activeColor.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: activeColor.withValues(alpha: 0.55),
            ),
          ),
          child: Text(
            text,
            style: TextStyle(
              color: activeColor,
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
            color: state.isTorchOn ? Colors.amberAccent : themeColor,
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
          icon: const Icon(
            Icons.photo_library_outlined,
            color: themeColor,
          ),
          label: const Text('相册导入'),
        );
      },
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
      title: '自定义扫码页 · 识别结果',
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
