import Flutter
import UIKit

#if canImport(xue_hua_barcode_scanner_ffi)
import xue_hua_barcode_scanner_ffi
#endif

/// Pure FFI iOS host for the barcode scanner plugin. Owns the Flutter texture
/// registry, permission dialogs, and gallery picker while dispatching native FFI
/// host operations without any `FlutterMethodChannel` or `FlutterEventChannel`.
public final class XueHuaBarcodeScannerPlugin: NSObject, FlutterPlugin {
    private static let registrationLock = NSLock()
    private static weak var activeInstance: XueHuaBarcodeScannerPlugin?

    private var cameraController: IOSCameraSessionController?
    private let galleryCoordinator = IOSGalleryPickerCoordinator()
    private var retainedUserData: UnsafeMutableRawPointer?

    public static func register(with registrar: FlutterPluginRegistrar) {
        _ = xh_host_retain_apple_ffi_symbols()

        registrationLock.lock()
        let previous = activeInstance
        registrationLock.unlock()
        previous?.teardownHost(unregisterTexture: true)

        let instance = XueHuaBarcodeScannerPlugin()
        instance.cameraController = IOSCameraSessionController(
            textureRegistry: registrar.textures()
        )

        let opaqueSelf = Unmanaged.passRetained(instance).toOpaque()
        instance.retainedUserData = opaqueSelf

        registrationLock.lock()
        activeInstance = instance
        registrationLock.unlock()

        var ops = XHHostPlatformOps(
            user_data: opaqueSelf,
            list_cameras: { userData, requestId in
                guard let userData else {
                    xh_host_complete_camera_list(requestId, 1, nil, nil, nil, 0)
                    return
                }
                let plugin = Unmanaged<XueHuaBarcodeScannerPlugin>
                    .fromOpaque(userData)
                    .takeUnretainedValue()
                plugin.cameraController?.listCameras(requestId: requestId)
            },
            start_camera: { userData, requestId, sessionGeneration, facingPtr, cameraIdPtr in
                let facing = facingPtr.map { String(cString: $0) } ?? "back"
                let cameraId = cameraIdPtr.map { String(cString: $0) }
                guard let userData else {
                    xh_host_complete_start_camera(
                        requestId,
                        0,
                        "NO_HOST",
                        "Native host is not attached.",
                        nil,
                        -1,
                        0,
                        0,
                        0,
                        nil,
                        facing,
                        0,
                        0,
                        0,
                        nil,
                        0
                    )
                    return
                }
                let plugin = Unmanaged<XueHuaBarcodeScannerPlugin>
                    .fromOpaque(userData)
                    .takeUnretainedValue()
                plugin.handleStartCamera(
                    requestId: requestId,
                    sessionGeneration: sessionGeneration,
                    facing: facing,
                    cameraId: cameraId
                )
            },
            stop_camera: { userData, requestId in
                guard let userData else {
                    if requestId != 0 {
                        xh_host_complete_bool(requestId, 1, 1, nil, nil)
                    }
                    return
                }
                let plugin = Unmanaged<XueHuaBarcodeScannerPlugin>
                    .fromOpaque(userData)
                    .takeUnretainedValue()
                plugin.cameraController?.stopCameraSession(requestId: requestId)
            },
            set_torch: { userData, requestId, enabled in
                guard let userData else {
                    xh_host_complete_bool(requestId, 1, 0, nil, nil)
                    return
                }
                let plugin = Unmanaged<XueHuaBarcodeScannerPlugin>
                    .fromOpaque(userData)
                    .takeUnretainedValue()
                plugin.cameraController?.setTorch(enabled: enabled != 0, requestId: requestId)
            },
            open_app_settings: { _, requestId in
                IOSPermissionAndSettingsHandler.openAppPermissionSettings(requestId: requestId)
            },
            pick_image: { userData, requestId, preferFilePath in
                guard let userData, preferFilePath == 0 else {
                    xh_host_complete_pick_image(requestId, 1, 0, nil, 0, nil, nil, nil)
                    return
                }
                let plugin = Unmanaged<XueHuaBarcodeScannerPlugin>
                    .fromOpaque(userData)
                    .takeUnretainedValue()
                plugin.galleryCoordinator.pickImageFromGallery(requestId: requestId)
            },
            set_frame_stream_paused: { userData, paused in
                guard let userData else { return }
                let plugin = Unmanaged<XueHuaBarcodeScannerPlugin>
                    .fromOpaque(userData)
                    .takeUnretainedValue()
                plugin.cameraController?.setFrameStreamPaused(paused != 0)
            }
        )
        xh_host_register_platform(&ops)
    }

    public func detachFromEngine(for registrar: FlutterPluginRegistrar) {
        teardownHost(unregisterTexture: true)
    }

    private func teardownHost(unregisterTexture: Bool) {
        Self.registrationLock.lock()
        if Self.activeInstance === self {
            Self.activeInstance = nil
        }
        let userData = retainedUserData
        retainedUserData = nil
        Self.registrationLock.unlock()

        if let userData {
            xh_host_unregister_platform(userData)
            Unmanaged<XueHuaBarcodeScannerPlugin>.fromOpaque(userData).release()
        }
        if unregisterTexture {
            cameraController?.unregisterTextureOnDetach()
        } else {
            cameraController?.stopCameraSession(requestId: 0)
        }
    }

    private func handleStartCamera(
        requestId: Int64,
        sessionGeneration: UInt64,
        facing: String,
        cameraId: String?
    ) {
        IOSPermissionAndSettingsHandler.checkOrRequestCameraAccess(
            requestId: requestId,
            facing: facing
        ) { [weak self] in
            self?.cameraController?.configureAndStartSession(
                requestId: requestId,
                sessionGeneration: sessionGeneration,
                facing: facing,
                cameraId: cameraId
            )
        }
    }
}
