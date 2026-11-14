import AVFoundation
import UIKit

#if canImport(xue_hua_barcode_scanner_ffi)
import xue_hua_barcode_scanner_ffi
#endif

/// Handles iOS camera authorization checks, permission requests, and opening
/// the application settings screen via the Pure FFI completion bridge.
enum IOSPermissionAndSettingsHandler {
    static func checkOrRequestCameraAccess(
        requestId: Int64,
        facing: String,
        onGranted: @escaping () -> Void
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
                    xh_host_complete_start_camera(
                        requestId,
                        0,
                        "CAMERA_PERMISSION_DENIED",
                        "Camera permission was denied by the user.",
                        "denied",
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
                }
            }
        case .restricted:
            xh_host_complete_start_camera(
                requestId,
                0,
                "CAMERA_PERMISSION_RESTRICTED",
                "Camera access is restricted by system policy.",
                "restricted",
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
        default:
            xh_host_complete_start_camera(
                requestId,
                0,
                "CAMERA_PERMISSION_DENIED",
                "Camera access is not authorized. Please enable camera access in Settings.",
                "permanentlyDenied",
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
        }
    }

    static func openAppPermissionSettings(requestId: Int64) {
        DispatchQueue.main.async {
            guard let url = URL(string: UIApplication.openSettingsURLString),
                  UIApplication.shared.canOpenURL(url)
            else {
                xh_host_complete_bool(requestId, 1, 0, nil, nil)
                return
            }
            UIApplication.shared.open(url, options: [:]) { success in
                xh_host_complete_bool(requestId, 1, success ? 1 : 0, nil, nil)
            }
        }
    }
}
