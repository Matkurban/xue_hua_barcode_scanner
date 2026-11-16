import 'dart:convert';
import 'dart:typed_data';

import 'package:material_ui/material_ui.dart';
import 'package:xue_hua_barcode_scanner/xue_hua_barcode_scanner.dart';

import '../widgets/scan_result_dialog.dart';

/// 演示使用自定义 UI Builder、挖孔方框模式、自定义二维码位置组件 [barcodeMarkerBuilder]、
/// 国际化 [XueHuaScannerTexts]、二维码校验 [validator] 与外部 [XueHuaScannerController] 构建的扫码页面。
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
      enableMultiBarcodeSelection: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color errorColor = Color(0xFFFF5252);
    const Color themeColor = Colors.cyanAccent;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          XueHuaBarcodeScannerPage(
            key: const ValueKey<String>('xh_custom_scanner_page'),
            controller: _controller,
            autoPopOnDetect: false,
            showCutoutOverlay: true,
            cutoutSize: 270,
            errorColor: errorColor,
            texts: const XueHuaScannerTexts(
              hintText: '将二维码放入框内 · 自定义赛博主题',
              multiBarcodeHintText: '点击任意赛博标签卡片，选择目标条码',
              cancelMultiSelectLabel: '返回重扫',
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
            barcodeMarkerBuilder:
                (
                  BuildContext context,
                  BarcodeMarkerInfo info,
                  VoidCallback onSelect,
                ) {
                  return GestureDetector(
                    onTap: onSelect,
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 168),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xE60B1324),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: themeColor, width: 1.6),
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: themeColor.withValues(alpha: 0.38),
                            blurRadius: 12,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Container(
                            width: 24,
                            height: 24,
                            decoration: const BoxDecoration(
                              color: themeColor,
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '${info.index + 1}',
                              style: const TextStyle(
                                color: Color(0xFF06101E),
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(width: 7),
                          Flexible(
                            child: Text(
                              info.result.text,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.ads_click_rounded,
                            color: themeColor,
                            size: 15,
                          ),
                        ],
                      ),
                    ),
                  );
                },
            overlayBuilder:
                (BuildContext context, Rect scanWindow, ScannerState state) {
                  final Color activeColor = state.hasValidationError
                      ? errorColor
                      : themeColor;
                  return XueHuaScannerOverlay(
                    scanWindow: scanWindow,
                    showCutout: true,
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
            scanLineBuilder:
                (
                  BuildContext context,
                  Animation<double> animation,
                  Rect scanWindow,
                ) {
                  return ValueListenableBuilder<ScannerState>(
                    valueListenable: _controller,
                    builder:
                        (BuildContext context, ScannerState state, Widget? _) {
                          return XueHuaScanLineAnimation(
                            animation: animation,
                            scanWindow: scanWindow,
                            lineColor: state.hasValidationError
                                ? errorColor
                                : themeColor,
                            glowHeight: 54,
                          );
                        },
                  );
                },
            hintTextBuilder: (BuildContext context, ScannerState state) {
              final bool isError = state.hasValidationError;
              final Color activeColor = isError ? errorColor : themeColor;
              final String text = isError
                  ? (state.lastGalleryScanStatus ==
                            GalleryScanStatus.noBarcodeFound
                        ? '所选图片未检测到有效二维码'
                        : '二维码校验未通过')
                  : (state.isSelectingMultiBarcode
                        ? '点击任意赛博标签卡片，选择目标条码'
                        : (state.isPaused ? '已暂停扫描' : '将二维码放入框内 · 自定义赛博主题'));
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: activeColor.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: activeColor.withValues(alpha: 0.55),
                  ),
                ),
                child: Text(
                  text,
                  key: const ValueKey<String>('xh_scanner_hint'),
                  style: TextStyle(
                    color: activeColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              );
            },
            torchButtonBuilder:
                (
                  BuildContext context,
                  ScannerState state,
                  VoidCallback onToggleTorch,
                ) {
                  return FilledButton.tonalIcon(
                    key: const ValueKey<String>('xh_scanner_torch_button'),
                    onPressed: onToggleTorch,
                    icon: Icon(
                      state.isTorchOn
                          ? Icons.flashlight_on
                          : Icons.flashlight_off,
                      color: state.isTorchOn ? Colors.amberAccent : themeColor,
                    ),
                    label: Text(state.isTorchOn ? '关闭闪光灯' : '开启闪光灯'),
                  );
                },
            galleryButtonBuilder:
                (
                  BuildContext context,
                  ScannerState state,
                  VoidCallback onPickGallery,
                ) {
                  return FilledButton.tonalIcon(
                    key: const ValueKey<String>('xh_scanner_gallery_button'),
                    onPressed: onPickGallery,
                    icon: const Icon(
                      Icons.photo_library_outlined,
                      color: themeColor,
                    ),
                    label: const Text('相册导入'),
                  );
                },
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
                    child: OutlinedButton.icon(
                      key: const ValueKey<String>(
                        'xh_custom_simulate_multi_barcode_button',
                      ),
                      onPressed: _simulateCustomMultiBarcodes,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: themeColor,
                        backgroundColor: const Color(0xB3050B14),
                        side: const BorderSide(color: themeColor),
                        visualDensity: VisualDensity.compact,
                      ),
                      icon: const Icon(Icons.hub_rounded, size: 16),
                      label: const Text(
                        '模拟多码自定义位置组件',
                        style: TextStyle(fontSize: 12),
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

  Future<void> _simulateCustomMultiBarcodes() async {
    const Size demoFrameSize = Size(390, 844);
    await _controller.simulateMultiBarcodeDetection(<BarcodeResult>[
      BarcodeResult(
        text: 'CYBER-NODE-01',
        rawBytes: Uint8List.fromList(utf8.encode('CYBER-NODE-01')),
        cornerPoints: const <Offset>[
          Offset(80, 260),
          Offset(160, 260),
          Offset(160, 340),
          Offset(80, 340),
        ],
        format: BarcodeFormat.qrCode,
        frameSize: demoFrameSize,
      ),
      BarcodeResult(
        text: 'CYBER-NODE-02',
        rawBytes: Uint8List.fromList(utf8.encode('CYBER-NODE-02')),
        cornerPoints: const <Offset>[
          Offset(220, 420),
          Offset(300, 420),
          Offset(300, 500),
          Offset(220, 500),
        ],
        format: BarcodeFormat.qrCode,
        frameSize: demoFrameSize,
      ),
    ]);
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
