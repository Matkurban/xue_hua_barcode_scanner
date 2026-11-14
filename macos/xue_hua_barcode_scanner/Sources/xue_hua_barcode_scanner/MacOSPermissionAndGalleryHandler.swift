import AppKit
import AVFoundation
import UniformTypeIdentifiers

#if canImport(xue_hua_barcode_scanner_ffi)
import xue_hua_barcode_scanner_ffi
#endif

/// Handles macOS camera permission authorization, opening System Settings -> Privacy & Security -> Camera,
/// and non-blocking image file picking via `NSOpenPanel`.
enum MacOSPermissionAndGalleryHandler {
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
                "Camera access is not authorized. Please enable camera access in System Settings > Privacy & Security > Camera.",
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

    static func openPrivacyCameraSettings(requestId: Int64) {
        DispatchQueue.main.async {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera") {
                let opened = NSWorkspace.shared.open(url)
                xh_host_complete_bool(requestId, 1, opened ? 1 : 0, nil, nil)
            } else {
                xh_host_complete_bool(requestId, 1, 0, nil, nil)
            }
        }
    }

    static func pickImageFromDisk(requestId: Int64) {
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

            let handleResponse: (NSApplication.ModalResponse) -> Void = { response in
                guard response == .OK, let url = panel.url else {
                    xh_host_complete_pick_image(requestId, 1, 0, nil, 0, nil, nil, nil)
                    return
                }
                DispatchQueue.global(qos: .userInitiated).async {
                    guard let data = try? Data(contentsOf: url), !data.isEmpty else {
                        xh_host_complete_pick_image(requestId, 1, 0, nil, 0, nil, nil, nil)
                        return
                    }
                    data.withUnsafeBytes { rawBuffer in
                        guard let base = rawBuffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                            xh_host_complete_pick_image(requestId, 1, 0, nil, 0, nil, nil, nil)
                            return
                        }
                        xh_host_complete_pick_image(
                            requestId,
                            1,
                            1,
                            base,
                            Int32(data.count),
                            nil,
                            nil,
                            nil
                        )
                    }
                }
            }

            if let hostWindow = NSApp.keyWindow ?? NSApp.mainWindow {
                panel.beginSheetModal(for: hostWindow, completionHandler: handleResponse)
            } else {
                panel.begin(completionHandler: handleResponse)
            }
        }
    }
}
