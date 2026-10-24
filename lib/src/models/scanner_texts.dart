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
    );
  }
}
