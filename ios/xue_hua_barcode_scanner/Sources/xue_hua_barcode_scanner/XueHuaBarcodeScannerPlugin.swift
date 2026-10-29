import Flutter
import UIKit

#if canImport(xue_hua_barcode_scanner_ffi)
import xue_hua_barcode_scanner_ffi
#endif

/// Main iOS Flutter plugin entry point. Delegates camera session lifecycle,
/// permission handling, luminance extraction, and photo picking to modular components.
public final class XueHuaBarcodeScannerPlugin: NSObject,
    FlutterPlugin,
    FlutterStreamHandler
{
    private var methodChannel: FlutterMethodChannel?
    private var eventChannel: FlutterEventChannel?
    private var eventSink: FlutterEventSink?

    private var cameraController: IOSCameraSessionController?
    private let galleryCoordinator = IOSGalleryPickerCoordinator()

    public static func register(with registrar: FlutterPluginRegistrar) {
        #if canImport(xue_hua_barcode_scanner_ffi)
        _ = zxing_engine_version()
        free_barcode_results(zxing_decode_image_bytes(nil, 0, 0, 0, 0, 0, 0, 0))
        free_encoded_barcode_image(zxing_encode_barcode(nil, 0, 0, 0, 0))
        #endif

        let instance = XueHuaBarcodeScannerPlugin()
        instance.cameraController = IOSCameraSessionController(
            textureRegistry: registrar.textures(),
            eventSinkProvider: { [weak instance] in instance?.eventSink }
        )

        let methodChannel = FlutterMethodChannel(
            name: "com.kurban.xue_hua_barcode_scanner/methods",
            binaryMessenger: registrar.messenger()
        )
        instance.methodChannel = methodChannel
        registrar.addMethodCallDelegate(instance, channel: methodChannel)

        let eventChannel = FlutterEventChannel(
            name: "com.kurban.xue_hua_barcode_scanner/frames",
            binaryMessenger: registrar.messenger()
        )
        instance.eventChannel = eventChannel
        eventChannel.setStreamHandler(instance)
    }

    public func detachFromEngine(for registrar: FlutterPluginRegistrar) {
        cameraController?.unregisterTextureOnDetach()
        methodChannel?.setMethodCallHandler(nil)
        eventChannel?.setStreamHandler(nil)
    }

    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        eventSink = events
        return nil
    }

    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        eventSink = nil
        return nil
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "listCameras":
            cameraController?.listCameras(result: result)
        case "startCamera":
            let args = call.arguments as? [String: Any]
            let facing = (args?["facing"] as? String) ?? "back"
            let cameraId = args?["cameraId"] as? String
            IOSPermissionAndSettingsHandler.checkOrRequestCameraAccess(
                onGranted: { [weak self] in
                    self?.cameraController?.configureAndStartSession(
                        facing: facing,
                        cameraId: cameraId,
                        result: result
                    )
                },
                result: result
            )
        case "stopCamera":
            cameraController?.stopCameraSession {
                DispatchQueue.main.async {
                    result(nil)
                }
            }
        case "setTorch":
            let args = call.arguments as? [String: Any]
            let enabled = (args?["enabled"] as? Bool) ?? false
            cameraController?.setTorch(enabled: enabled, result: result)
        case "openAppSettings":
            IOSPermissionAndSettingsHandler.openAppPermissionSettings(result: result)
        case "pickImageFromGallery":
            galleryCoordinator.pickImageFromGallery(result: result)
        case "pickImageFilePath":
            result(nil)
        default:
            result(FlutterMethodNotImplemented)
        }
    }
}
