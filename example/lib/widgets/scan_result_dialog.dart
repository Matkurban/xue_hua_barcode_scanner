import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:xue_hua_barcode_scanner/xue_hua_barcode_scanner.dart';

import 'barcode_result_tile.dart';

/// 扫码页面识别出条码/二维码后弹出的结果详情对话框组件。
class ScanResultDialog extends StatelessWidget {
  const ScanResultDialog({
    super.key,
    required this.title,
    required this.results,
  });

  /// 对话框标题。
  final String title;

  /// 本次识别到的条码/二维码结果列表。
  final List<BarcodeResult> results;

  /// 在当前扫码页面弹出识别结果对话框。
  ///
  /// 返回 `true` 表示用户点击了“确定返回”，返回 `false` 或 `null` 表示“继续扫码”。
  static Future<bool?> show(
    BuildContext context, {
    required List<BarcodeResult> results,
    String title = '扫码识别结果',
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return ScanResultDialog(title: title, results: results);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final String combinedText = results
        .map((BarcodeResult item) => item.text)
        .join('\n');

    return AlertDialog(
      key: const ValueKey<String>('xh_scan_result_dialog'),
      backgroundColor: const Color(0xFF1A1D24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
      ),
      title: Row(
        children: <Widget>[
          const Icon(
            Icons.check_circle_rounded,
            color: Color(0xFF00E676),
            size: 24,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$title (${results.length})',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420, maxHeight: 360),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              for (final BarcodeResult item in results)
                BarcodeResultTile(result: item),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton.icon(
          key: const ValueKey<String>('xh_scan_result_copy'),
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: combinedText));
            if (!context.mounted) return;
            ScaffoldMessenger.maybeOf(context)?.showSnackBar(
              const SnackBar(
                content: Text('已复制条码内容到剪贴板'),
                duration: Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
              ),
            );
          },
          icon: const Icon(Icons.copy_rounded, size: 18),
          label: const Text('复制内容'),
        ),
        OutlinedButton(
          key: const ValueKey<String>('xh_scan_result_continue'),
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('继续扫码'),
        ),
        FilledButton(
          key: const ValueKey<String>('xh_scan_result_confirm'),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF00E676),
            foregroundColor: Colors.black,
          ),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('确定返回'),
        ),
      ],
    );
  }
}
