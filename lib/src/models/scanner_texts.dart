/// Encapsulates all customizable UI text strings in `XueHuaBarcodeScannerPage`
/// and `XueHuaScannerView` for internationalization (i18n) and localization.
class XueHuaScannerTexts {
  /// Creates a [XueHuaScannerTexts] configuration with localized strings.
  const XueHuaScannerTexts({
    this.hintText = '将二维码放入框内',
    this.invalidBarcodeText = '二维码不符合要求',
    this.noBarcodeInImageText = '未在所选图片中识别到二维码或条码',
    this.torchOnLabel = '轻触关闭',
    this.torchOffLabel = '手电筒',
    this.galleryLabel = '相册',
    this.backButtonTooltip = '返回',
    this.switchCameraTooltip = '切换前后摄像头',
    this.selectInputSourceTooltip = '选择输入源',
    this.torchUnsupportedMessage = '当前摄像头或桌面设备不支持手电筒闪光灯',
    this.cameraUnavailablePrefix = '相机不可用: ',
    this.frontCameraPreviewText = '前置相机取景中',
    this.backCameraPreviewText = '后置相机取景中',
    this.permissionDeniedTitle = '未获得相机访问权限',
    this.permissionDeniedDescription = '实时扫码需要访问摄像头画面。请前往系统设置开启相机权限，或直接从相册选图识别。',
    this.permissionRestrictedDescription = '当前设备的相机访问受到系统安全策略或家长控制限制，您仍可通过相册导入图片进行扫码。',
    this.permissionGuideStep1 = '点击下方「前往系统设置」打开应用权限页',
    this.permissionGuideStep2 = '开启「相机 / 摄像头」访问权限开关',
    this.permissionGuideStep3 = '返回本页面将自动恢复实时扫码取景',
    this.openSettingsButtonLabel = '前往系统设置',
    this.retryPermissionButtonLabel = '重新授权 / 重试',
    this.useGalleryFallbackButtonLabel = '从相册选择图片扫码',
    this.noCameraHardwareTitle = '未检测到可用摄像头',
    this.noCameraHardwareDescription = '当前设备未连接摄像头或视频驱动未就绪，您可点击重试或直接从相册选图解码。',
    this.cameraErrorTitle = '相机画面暂时无法开启',
    this.cameraInitializingTitle = '正在启动相机取景...',
  });

  /// Prompt displayed in the top region during normal scanning.
  final String hintText;

  /// Prompt and error feedback displayed when a scanned barcode fails validation.
  final String invalidBarcodeText;

  /// Feedback message displayed when a gallery image contains no recognizable barcode.
  final String noBarcodeInImageText;

  /// Label displayed below the torch button when the flashlight is active.
  final String torchOnLabel;

  /// Label displayed below the torch button when the flashlight is off.
  final String torchOffLabel;

  /// Label displayed below the gallery picker button.
  final String galleryLabel;

  /// Tooltip for the top-left back navigation button.
  final String backButtonTooltip;

  /// Tooltip for the top-right camera switch button.
  final String switchCameraTooltip;

  /// Tooltip for the input-source button shown when several cameras are available.
  final String selectInputSourceTooltip;

  /// Message shown when the user taps the torch button on a device without flash.
  final String torchUnsupportedMessage;

  /// Prefix shown when camera initialization fails with an error.
  final String cameraUnavailablePrefix;

  /// Placeholder label shown while the front camera stream is initializing.
  final String frontCameraPreviewText;

  /// Placeholder label shown while the rear camera stream is initializing.
  final String backCameraPreviewText;

  /// Primary title shown on the camera canvas when camera permission is denied.
  final String permissionDeniedTitle;

  /// Subtitle explanation shown when camera permission is denied.
  final String permissionDeniedDescription;

  /// Subtitle explanation shown when camera access is restricted by system policy.
  final String permissionRestrictedDescription;

  /// Step 1 of the permission recovery guide.
  final String permissionGuideStep1;

  /// Step 2 of the permission recovery guide.
  final String permissionGuideStep2;

  /// Step 3 of the permission recovery guide.
  final String permissionGuideStep3;

  /// Button label to open OS system settings for camera permission.
  final String openSettingsButtonLabel;

  /// Button label to re-request permission or retry starting the camera.
  final String retryPermissionButtonLabel;

  /// Button label on the permission/error card to pick a barcode image from gallery.
  final String useGalleryFallbackButtonLabel;

  /// Title shown when no physical camera hardware is detected.
  final String noCameraHardwareTitle;

  /// Description shown when no physical camera hardware is detected.
  final String noCameraHardwareDescription;

  /// Title shown when camera initialization encounters a general hardware error.
  final String cameraErrorTitle;

  /// Label shown while the camera session is starting up.
  final String cameraInitializingTitle;

  /// Creates a copy of this [XueHuaScannerTexts] with selected fields replaced.
  XueHuaScannerTexts copyWith({
    String? hintText,
    String? invalidBarcodeText,
    String? noBarcodeInImageText,
    String? torchOnLabel,
    String? torchOffLabel,
    String? galleryLabel,
    String? backButtonTooltip,
    String? switchCameraTooltip,
    String? selectInputSourceTooltip,
    String? torchUnsupportedMessage,
    String? cameraUnavailablePrefix,
    String? frontCameraPreviewText,
    String? backCameraPreviewText,
    String? permissionDeniedTitle,
    String? permissionDeniedDescription,
    String? permissionRestrictedDescription,
    String? permissionGuideStep1,
    String? permissionGuideStep2,
    String? permissionGuideStep3,
    String? openSettingsButtonLabel,
    String? retryPermissionButtonLabel,
    String? useGalleryFallbackButtonLabel,
    String? noCameraHardwareTitle,
    String? noCameraHardwareDescription,
    String? cameraErrorTitle,
    String? cameraInitializingTitle,
  }) {
    return XueHuaScannerTexts(
      hintText: hintText ?? this.hintText,
      invalidBarcodeText: invalidBarcodeText ?? this.invalidBarcodeText,
      noBarcodeInImageText: noBarcodeInImageText ?? this.noBarcodeInImageText,
      torchOnLabel: torchOnLabel ?? this.torchOnLabel,
      torchOffLabel: torchOffLabel ?? this.torchOffLabel,
      galleryLabel: galleryLabel ?? this.galleryLabel,
      backButtonTooltip: backButtonTooltip ?? this.backButtonTooltip,
      switchCameraTooltip: switchCameraTooltip ?? this.switchCameraTooltip,
      selectInputSourceTooltip:
          selectInputSourceTooltip ?? this.selectInputSourceTooltip,
      torchUnsupportedMessage:
          torchUnsupportedMessage ?? this.torchUnsupportedMessage,
      cameraUnavailablePrefix:
          cameraUnavailablePrefix ?? this.cameraUnavailablePrefix,
      frontCameraPreviewText:
          frontCameraPreviewText ?? this.frontCameraPreviewText,
      backCameraPreviewText:
          backCameraPreviewText ?? this.backCameraPreviewText,
      permissionDeniedTitle:
          permissionDeniedTitle ?? this.permissionDeniedTitle,
      permissionDeniedDescription:
          permissionDeniedDescription ?? this.permissionDeniedDescription,
      permissionRestrictedDescription:
          permissionRestrictedDescription ??
          this.permissionRestrictedDescription,
      permissionGuideStep1: permissionGuideStep1 ?? this.permissionGuideStep1,
      permissionGuideStep2: permissionGuideStep2 ?? this.permissionGuideStep2,
      permissionGuideStep3: permissionGuideStep3 ?? this.permissionGuideStep3,
      openSettingsButtonLabel:
          openSettingsButtonLabel ?? this.openSettingsButtonLabel,
      retryPermissionButtonLabel:
          retryPermissionButtonLabel ?? this.retryPermissionButtonLabel,
      useGalleryFallbackButtonLabel:
          useGalleryFallbackButtonLabel ?? this.useGalleryFallbackButtonLabel,
      noCameraHardwareTitle:
          noCameraHardwareTitle ?? this.noCameraHardwareTitle,
      noCameraHardwareDescription:
          noCameraHardwareDescription ?? this.noCameraHardwareDescription,
      cameraErrorTitle: cameraErrorTitle ?? this.cameraErrorTitle,
      cameraInitializingTitle:
          cameraInitializingTitle ?? this.cameraInitializingTitle,
    );
  }
}
