import 'package:material_ui/material_ui.dart';

import '../../controller/barcode_scanner.dart';
import '../../models/barcode_enums.dart';
import '../../models/scanner_state.dart';
import '../../models/scanner_texts.dart';
import '../scanner_builders.dart';

/// Renders the live platform camera feed (`Texture` on native, `HtmlElementView` on Web),
/// or a specially designed camera permission / hardware diagnostic surface when
/// the camera stream is unauthorized or unavailable.
class ScannerCameraPreview extends StatelessWidget {
  const ScannerCameraPreview({
    super.key,
    required this.isWeb,
    required this.state,
    required this.texts,
    this.scanWindow,
    this.accentColor = const Color(0xFF00E676),
    this.permissionDeniedBuilder,
    this.onOpenSettings,
    this.onRetryPermission,
    this.onPickGallery,
  });

  final bool isWeb;
  final ScannerState state;
  final XueHuaScannerTexts texts;
  final Rect? scanWindow;
  final Color accentColor;
  final XueHuaPermissionDeniedBuilder? permissionDeniedBuilder;
  final VoidCallback? onOpenSettings;
  final VoidCallback? onRetryPermission;
  final VoidCallback? onPickGallery;

  @override
  Widget build(BuildContext context) {
    if (isWeb && state.webViewType != null) {
      return RepaintBoundary(
        child: SizedBox.expand(
          child: HtmlElementView(viewType: state.webViewType!),
        ),
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

      return RepaintBoundary(
        child: SizedBox.expand(
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
        ),
      );
    }

    if (state.isPermissionDenied) {
      if (permissionDeniedBuilder != null) {
        return permissionDeniedBuilder!(
          context,
          state,
          onOpenSettings ?? () {},
          onRetryPermission ?? () {},
          onPickGallery ?? () {},
        );
      }
      return RepaintBoundary(
        child: _CameraPermissionDeniedSurface(
          state: state,
          texts: texts,
          accentColor: accentColor,
          onOpenSettings: onOpenSettings,
          onRetryPermission: onRetryPermission,
          onPickGallery: onPickGallery,
        ),
      );
    }

    if (state.hasCameraError) {
      return RepaintBoundary(
        child: _CameraHardwareDiagnosticSurface(
          state: state,
          texts: texts,
          accentColor: accentColor,
          onRetryPermission: onRetryPermission,
          onPickGallery: onPickGallery,
        ),
      );
    }

    final String statusText = !state.isInitialized
        ? texts.cameraInitializingTitle
        : (state.cameraFacing == CameraFacing.front
              ? '${texts.frontCameraPreviewText} (${XueHuaBarcodeScanner.engineVersion})'
              : '${texts.backCameraPreviewText} (${XueHuaBarcodeScanner.engineVersion})');

    return RepaintBoundary(
      child: _CameraStandbyViewfinderSurface(
        statusText: statusText,
        scanWindow: scanWindow,
        accentColor: accentColor,
        isInitializing: !state.isInitialized,
      ),
    );
  }
}

/// Comprehensive, specially designed camera surface when camera permission is
/// denied or restricted (`state.isPermissionDenied == true`).
class _CameraPermissionDeniedSurface extends StatelessWidget {
  const _CameraPermissionDeniedSurface({
    required this.state,
    required this.texts,
    required this.accentColor,
    required this.onOpenSettings,
    required this.onRetryPermission,
    required this.onPickGallery,
  });

  final ScannerState state;
  final XueHuaScannerTexts texts;
  final Color accentColor;
  final VoidCallback? onOpenSettings;
  final VoidCallback? onRetryPermission;
  final VoidCallback? onPickGallery;

  @override
  Widget build(BuildContext context) {
    const Color warningAmber = Color(0xFFF59E0B);
    const Color warningCoral = Color(0xFFFB7185);
    final bool isRestricted = state.isPermissionRestricted;
    final String diagnosticText =
        '${texts.cameraUnavailablePrefix}${state.errorMessage ?? state.errorCode ?? "CAMERA_PERMISSION_DENIED"}';

    return DecoratedBox(
      key: const ValueKey<String>('xh_scanner_permission_denied_view'),
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0.0, -0.15),
          radius: 1.15,
          colors: <Color>[
            Color(0xFF231B2E),
            Color(0xFF111827),
            Color(0xFF070A12),
          ],
          stops: <double>[0.0, 0.55, 1.0],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          const CustomPaint(painter: _StaticViewfinderGridPainter()),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(
                  top: 68,
                  bottom: 112,
                  left: 20,
                  right: 20,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 368),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: <Color>[Color(0xE61E293B), Color(0xF20F172A)],
                      ),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: warningAmber.withValues(alpha: 0.38),
                        width: 1.2,
                      ),
                      boxShadow: const <BoxShadow>[
                        BoxShadow(
                          color: Color(0x80000000),
                          blurRadius: 32,
                          offset: Offset(0, 14),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        // Hero layered camera & security shield badge
                        SizedBox(
                          width: 76,
                          height: 76,
                          child: Stack(
                            alignment: Alignment.center,
                            children: <Widget>[
                              Container(
                                width: 72,
                                height: 72,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: RadialGradient(
                                    colors: <Color>[
                                      warningAmber.withValues(alpha: 0.28),
                                      warningCoral.withValues(alpha: 0.06),
                                    ],
                                  ),
                                  border: Border.all(
                                    color: warningAmber.withValues(alpha: 0.45),
                                    width: 1.5,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.no_photography_rounded,
                                  color: warningAmber,
                                  size: 34,
                                ),
                              ),
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0F172A),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: warningAmber,
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Icon(
                                    isRestricted
                                        ? Icons.policy_rounded
                                        : Icons.lock_rounded,
                                    color: warningAmber,
                                    size: 15,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: warningAmber.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: warningAmber.withValues(alpha: 0.35),
                            ),
                          ),
                          child: Text(
                            isRestricted ? '系统安全策略限制' : '相机权限未开启',
                            style: const TextStyle(
                              color: warningAmber,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          texts.permissionDeniedTitle,
                          key: const ValueKey<String>(
                            'xh_scanner_permission_title',
                          ),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          isRestricted
                              ? texts.permissionRestrictedDescription
                              : texts.permissionDeniedDescription,
                          key: const ValueKey<String>(
                            'xh_scanner_permission_description',
                          ),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xCCFFFFFF),
                            fontSize: 13,
                            height: 1.45,
                          ),
                        ),
                        if (!isRestricted) ...<Widget>[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.28),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.08),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                _PermissionGuideRow(
                                  stepNumber: '1',
                                  text: texts.permissionGuideStep1,
                                  accentColor: warningAmber,
                                ),
                                const SizedBox(height: 8),
                                _PermissionGuideRow(
                                  stepNumber: '2',
                                  text: texts.permissionGuideStep2,
                                  accentColor: warningAmber,
                                ),
                                const SizedBox(height: 8),
                                _PermissionGuideRow(
                                  stepNumber: '3',
                                  text: texts.permissionGuideStep3,
                                  accentColor: accentColor,
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 18),
                        if (!isRestricted && onOpenSettings != null)
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              key: const ValueKey<String>(
                                'xh_scanner_open_settings_button',
                              ),
                              onPressed: onOpenSettings,
                              style: FilledButton.styleFrom(
                                backgroundColor: warningAmber,
                                foregroundColor: const Color(0xFF0F172A),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                  horizontal: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              icon: const Icon(
                                Icons.settings_suggest_rounded,
                                size: 19,
                              ),
                              label: Text(
                                texts.openSettingsButtonLabel,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                        if (onRetryPermission != null) ...<Widget>[
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              key: const ValueKey<String>(
                                'xh_scanner_retry_permission_button',
                              ),
                              onPressed: onRetryPermission,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: BorderSide(
                                  color: Colors.white.withValues(alpha: 0.24),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 11,
                                  horizontal: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              icon: const Icon(Icons.refresh_rounded, size: 18),
                              label: Text(
                                texts.retryPermissionButtonLabel,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13.5,
                                ),
                              ),
                            ),
                          ),
                        ],
                        if (onPickGallery != null) ...<Widget>[
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: TextButton.icon(
                              key: const ValueKey<String>(
                                'xh_scanner_permission_gallery_button',
                              ),
                              onPressed: onPickGallery,
                              style: TextButton.styleFrom(
                                foregroundColor: accentColor,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                  horizontal: 12,
                                ),
                              ),
                              icon: const Icon(
                                Icons.photo_library_rounded,
                                size: 18,
                              ),
                              label: Text(
                                texts.useGalleryFallbackButtonLabel,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13.5,
                                ),
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            diagnosticText,
                            key: const ValueKey<String>(
                              'xh_scanner_camera_status',
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0x88FFFFFF),
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PermissionGuideRow extends StatelessWidget {
  const _PermissionGuideRow({
    required this.stepNumber,
    required this.text,
    required this.accentColor,
  });

  final String stepNumber;
  final String text;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: accentColor.withValues(alpha: 0.20),
            shape: BoxShape.circle,
            border: Border.all(color: accentColor.withValues(alpha: 0.55)),
          ),
          alignment: Alignment.center,
          child: Text(
            stepNumber,
            style: TextStyle(
              color: accentColor,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: Color(0xD9FFFFFF),
              fontSize: 12.2,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}

/// Hardware / driver diagnostic surface when no camera is connected or
/// hardware initialization fails (`state.hasCameraError && !state.isPermissionDenied`).
class _CameraHardwareDiagnosticSurface extends StatelessWidget {
  const _CameraHardwareDiagnosticSurface({
    required this.state,
    required this.texts,
    required this.accentColor,
    required this.onRetryPermission,
    required this.onPickGallery,
  });

  final ScannerState state;
  final XueHuaScannerTexts texts;
  final Color accentColor;
  final VoidCallback? onRetryPermission;
  final VoidCallback? onPickGallery;

  @override
  Widget build(BuildContext context) {
    final String title = state.isNoCameraHardware
        ? texts.noCameraHardwareTitle
        : texts.cameraErrorTitle;
    final String statusText =
        '${texts.cameraUnavailablePrefix}${state.errorMessage ?? state.errorCode ?? "NO_CAMERA"}';

    return DecoratedBox(
      key: const ValueKey<String>('xh_scanner_hardware_error_view'),
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
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          const CustomPaint(painter: _StaticViewfinderGridPainter()),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(
                  top: 68,
                  bottom: 112,
                  left: 24,
                  right: 24,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 340),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 22,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xD9151C28),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.14),
                      ),
                      boxShadow: const <BoxShadow>[
                        BoxShadow(
                          color: Color(0x66000000),
                          blurRadius: 24,
                          offset: Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.18),
                            ),
                          ),
                          child: const Icon(
                            Icons.videocam_off_rounded,
                            color: Colors.white70,
                            size: 28,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          texts.noCameraHardwareDescription,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xB3FFFFFF),
                            fontSize: 12.5,
                            height: 1.45,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            if (onRetryPermission != null)
                              OutlinedButton.icon(
                                key: const ValueKey<String>(
                                  'xh_scanner_retry_permission_button',
                                ),
                                onPressed: onRetryPermission,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  side: BorderSide(
                                    color: Colors.white.withValues(alpha: 0.22),
                                  ),
                                ),
                                icon: const Icon(
                                  Icons.refresh_rounded,
                                  size: 16,
                                ),
                                label: const Text(
                                  '重试',
                                  style: TextStyle(fontSize: 12.5),
                                ),
                              ),
                            if (onRetryPermission != null &&
                                onPickGallery != null)
                              const SizedBox(width: 10),
                            if (onPickGallery != null)
                              FilledButton.tonalIcon(
                                key: const ValueKey<String>(
                                  'xh_scanner_permission_gallery_button',
                                ),
                                onPressed: onPickGallery,
                                icon: const Icon(
                                  Icons.photo_library_rounded,
                                  size: 16,
                                ),
                                label: Text(
                                  texts.galleryLabel,
                                  style: const TextStyle(fontSize: 12.5),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          statusText,
                          key: const ValueKey<String>(
                            'xh_scanner_camera_status',
                          ),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0x8AFFFFFF),
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Atmospheric viewfinder background with a docked HUD status pill used when
/// initializing or running in simulated/unbound preview mode.
class _CameraStandbyViewfinderSurface extends StatelessWidget {
  const _CameraStandbyViewfinderSurface({
    required this.statusText,
    required this.scanWindow,
    required this.accentColor,
    required this.isInitializing,
  });

  final String statusText;
  final Rect? scanWindow;
  final Color accentColor;
  final bool isInitializing;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.center,
          radius: 1.1,
          colors: <Color>[
            Color(0xFF1B2538),
            Color(0xFF0E1525),
            Color(0xFF060911),
          ],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          const CustomPaint(painter: _StaticViewfinderGridPainter()),
          Align(
            alignment: const Alignment(0.0, 0.48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: const Color(0x800F172A),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(
                      isInitializing
                          ? Icons.hourglass_top_rounded
                          : Icons.sensors_rounded,
                      color: accentColor.withValues(alpha: 0.85),
                      size: 14,
                    ),
                    const SizedBox(width: 7),
                    Flexible(
                      child: Text(
                        statusText,
                        key: const ValueKey<String>('xh_scanner_camera_status'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xB3FFFFFF),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Static architectural camera grid painted once (`shouldRepaint => false`).
class _StaticViewfinderGridPainter extends CustomPainter {
  const _StaticViewfinderGridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final Paint gridPaint = Paint()
      ..color = const Color(0x09FFFFFF)
      ..strokeWidth = 1.0;

    const double step = 48.0;
    for (double x = step; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = step; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _StaticViewfinderGridPainter oldDelegate) =>
      false;
}
