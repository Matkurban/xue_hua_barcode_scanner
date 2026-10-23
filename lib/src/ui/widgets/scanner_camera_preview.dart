import 'package:material_ui/material_ui.dart';

import '../../controller/barcode_scanner.dart';
import '../../models/barcode_enums.dart';
import '../../models/scanner_state.dart';
import '../../models/scanner_texts.dart';

/// Renders the live platform camera feed (`Texture` on native, `HtmlElementView` on Web).
class ScannerCameraPreview extends StatelessWidget {
  const ScannerCameraPreview({
    super.key,
    required this.isWeb,
    required this.state,
    required this.texts,
  });

  final bool isWeb;
  final ScannerState state;
  final XueHuaScannerTexts texts;

  @override
  Widget build(BuildContext context) {
    if (isWeb && state.webViewType != null) {
      return SizedBox.expand(
        child: HtmlElementView(viewType: state.webViewType!),
      );
    }

    if (state.textureId != null) {
      final bool swapDimensions =
          state.sensorOrientation == 90 || state.sensorOrientation == 270;
      final double orientedWidth = swapDimensions
          ? state.previewSize.height
          : state.previewSize.width;
      final double orientedHeight = swapDimensions
          ? state.previewSize.width
          : state.previewSize.height;
      final double safeWidth = orientedWidth > 0 ? orientedWidth : 1280;
      final double safeHeight = orientedHeight > 0 ? orientedHeight : 720;

      return SizedBox.expand(
        child: ClipRect(
          child: FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: safeWidth,
              height: safeHeight,
              child: Texture(textureId: state.textureId!),
            ),
          ),
        ),
      );
    }

    final String statusText = state.errorMessage != null
        ? '${texts.cameraUnavailablePrefix}${state.errorMessage}'
        : (state.cameraFacing == CameraFacing.front
              ? '${texts.frontCameraPreviewText} (${XueHuaBarcodeScanner.engineVersion})'
              : '${texts.backCameraPreviewText} (${XueHuaBarcodeScanner.engineVersion})');

    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.center,
          radius: 1.1,
          colors: <Color>[
            Color(0xFF1E293B),
            Color(0xFF0F172A),
            Color(0xFF060911),
          ],
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.only(top: 260, left: 24, right: 24),
          child: Text(
            statusText,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0x99FFFFFF), fontSize: 12),
          ),
        ),
      ),
    );
  }
}
