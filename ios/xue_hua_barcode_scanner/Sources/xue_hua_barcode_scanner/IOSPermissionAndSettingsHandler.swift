import AVFoundation
import Flutter
import UIKit

/// Handles iOS camera authorization checks, permission requests, and opening
/// the application settings screen.
enum IOSPermissionAndSettingsHandler {
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
                    message: "Camera access is not authorized. Please enable camera access in Settings.",
                    details: "permanentlyDenied"
                )
            )
        }
    }

    static func openAppPermissionSettings(result: @escaping FlutterResult) {
        DispatchQueue.main.async {
            guard let url = URL(string: UIApplication.openSettingsURLString),
                  UIApplication.shared.canOpenURL(url)
            else {
                result(false)
                return
            }
            UIApplication.shared.open(url, options: [:]) { success in
                result(success)
            }
        }
    }
}
