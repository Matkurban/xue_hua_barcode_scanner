import AppKit
import AVFoundation
import FlutterMacOS
import UniformTypeIdentifiers

/// Handles macOS camera permission authorization, opening System Settings -> Privacy & Security -> Camera,
/// and picking local image files via `NSOpenPanel`.
enum MacOSPermissionAndGalleryHandler {
    static func checkOrRequestCameraAccess(
        onGranted: @escaping () -> Void,
        result: @escaping FlutterResult
    ) {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            onGranted()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                if granted {
                    onGranted()
                } else {
                    DispatchQueue.main.async {
                        result(
                            FlutterError(
                                code: "CAMERA_PERMISSION_DENIED",
                                message: "Camera permission was denied by the user.",
                                details: "denied"
                            )
                        )
                    }
                }
            }
        case .restricted:
            result(
                FlutterError(
                    code: "CAMERA_PERMISSION_RESTRICTED",
                    message: "Camera access is restricted by system policy.",
                    details: "restricted"
                )
            )
        default:
            result(
                FlutterError(
                    code: "CAMERA_PERMISSION_DENIED",
                    message: "Camera access is not authorized. Please enable camera access in System Settings > Privacy & Security > Camera.",
                    details: "permanentlyDenied"
                )
            )
        }
    }

    static func openPrivacyCameraSettings(result: @escaping FlutterResult) {
        DispatchQueue.main.async {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera") {
                let opened = NSWorkspace.shared.open(url)
                result(opened)
            } else {
                result(false)
            }
        }
    }

    static func pickImageFromDisk(result: @escaping FlutterResult) {
        DispatchQueue.main.async {
            let panel = NSOpenPanel()
            panel.canChooseFiles = true
            panel.canChooseDirectories = false
            panel.allowsMultipleSelection = false
            if #available(macOS 11.0, *) {
                panel.allowedContentTypes = [.image]
            } else {
                panel.allowedFileTypes = ["png", "jpg", "jpeg", "webp", "bmp", "heic"]
            }
            let response = panel.runModal()
            guard response == .OK,
                  let url = panel.url,
                  let data = try? Data(contentsOf: url)
            else {
                result(nil)
                return
            }
            result(FlutterStandardTypedData(bytes: data))
        }
    }
}
