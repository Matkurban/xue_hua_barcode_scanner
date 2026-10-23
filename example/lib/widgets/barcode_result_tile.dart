import 'package:material_ui/material_ui.dart';
import 'package:xue_hua_barcode_scanner/xue_hua_barcode_scanner.dart';

/// 单条解码结果与定位角点信息展示组件。
class BarcodeResultTile extends StatelessWidget {
  const BarcodeResultTile({
    super.key,
    required this.result,
  });

  final BarcodeResult result;

  @override
  Widget build(BuildContext context) {
    final String cornersText = result.cornerPoints
        .map((Offset p) => '(${p.dx.toInt()}, ${p.dy.toInt()})')
        .join(' -> ');

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: SelectableText(
        '内容: ${result.text}\n'
        '格式: ${result.format.displayName} | 校验有效: ${result.isValid}\n'
        '中心锚点: (${result.centerPoint.dx.toStringAsFixed(1)}, ${result.centerPoint.dy.toStringAsFixed(1)})\n'
        '4个定位角点: $cornersText',
        style: const TextStyle(fontSize: 12.5, height: 1.5),
      ),
    );
  }
}
