import UIKit

#if canImport(xue_hua_barcode_scanner_ffi)
import xue_hua_barcode_scanner_ffi
#endif

/// Coordinates presenting the iOS photo library picker (`UIImagePickerController`),
/// normalizing EXIF orientation, and returning PNG/JPEG bytes through the Pure FFI bridge.
final class IOSGalleryPickerCoordinator: NSObject,
    UIImagePickerControllerDelegate,
    UINavigationControllerDelegate
{
    private var pendingRequestId: Int64 = 0

    func pickImageFromGallery(requestId: Int64) {
        DispatchQueue.main.async { [weak self] in
            guard let self else {
                xh_host_complete_pick_image(requestId, 1, 0, nil, 0, nil, nil, nil)
                return
            }
            if self.pendingRequestId != 0 {
                let superseded = self.pendingRequestId
                self.pendingRequestId = 0
                xh_host_complete_pick_image(superseded, 1, 0, nil, 0, nil, nil, nil)
            }
            guard UIImagePickerController.isSourceTypeAvailable(.photoLibrary),
                  let presenter = Self.topViewController()
            else {
                xh_host_complete_pick_image(requestId, 1, 0, nil, 0, nil, nil, nil)
                return
            }
            self.pendingRequestId = requestId
            let picker = UIImagePickerController()
            picker.sourceType = .photoLibrary
            picker.delegate = self
            presenter.present(picker, animated: true)
        }
    }

    func imagePickerController(
        _ picker: UIImagePickerController,
        didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
    ) {
        picker.dismiss(animated: true)
        let reqId = pendingRequestId
        pendingRequestId = 0
        guard reqId != 0 else {
            return
        }
        guard let image = info[.originalImage] as? UIImage else {
            xh_host_complete_pick_image(reqId, 1, 0, nil, 0, nil, nil, nil)
            return
        }

        let normalizedImage: UIImage
        if image.imageOrientation == .up {
            normalizedImage = image
        } else {
            let renderer = UIGraphicsImageRenderer(size: image.size)
            normalizedImage = renderer.image { _ in
                image.draw(in: CGRect(origin: .zero, size: image.size))
            }
        }

        DispatchQueue.global(qos: .userInitiated).async {
            guard let imageData = normalizedImage.pngData()
                ?? normalizedImage.jpegData(compressionQuality: 0.95),
                  !imageData.isEmpty
            else {
                xh_host_complete_pick_image(reqId, 1, 0, nil, 0, nil, nil, nil)
                return
            }
            imageData.withUnsafeBytes { rawBuffer in
                guard let base = rawBuffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                    xh_host_complete_pick_image(reqId, 1, 0, nil, 0, nil, nil, nil)
                    return
                }
                xh_host_complete_pick_image(
                    reqId,
                    1,
                    1,
                    base,
                    Int32(imageData.count),
                    nil,
                    nil,
                    nil
                )
            }
        }
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
        let reqId = pendingRequestId
        pendingRequestId = 0
        if reqId != 0 {
            xh_host_complete_pick_image(reqId, 1, 0, nil, 0, nil, nil, nil)
        }
    }

    private static func topViewController() -> UIViewController? {
        var rootVC: UIViewController?
        for scene in UIApplication.shared.connectedScenes {
            if let windowScene = scene as? UIWindowScene {
                for window in windowScene.windows where window.isKeyWindow {
                    rootVC = window.rootViewController
                    break
                }
                if rootVC == nil {
                    rootVC = windowScene.windows.first?.rootViewController
                }
            }
            if rootVC != nil {
                break
            }
        }
        var current = rootVC
        while let presented = current?.presentedViewController {
            current = presented
        }
        return current
    }
}
