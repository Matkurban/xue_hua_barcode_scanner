import Flutter
import UIKit

/// Coordinates presenting the iOS photo library picker (`UIImagePickerController`),
/// normalizing EXIF orientation, and returning PNG/JPEG bytes to Flutter.
final class IOSGalleryPickerCoordinator: NSObject,
    UIImagePickerControllerDelegate,
    UINavigationControllerDelegate
{
    private var pendingPickerResult: FlutterResult?

    func pickImageFromGallery(result: @escaping FlutterResult) {
        DispatchQueue.main.async { [weak self] in
            guard let self else {
                result(nil)
                return
            }
            guard UIImagePickerController.isSourceTypeAvailable(.photoLibrary),
                  let presenter = Self.topViewController()
            else {
                result(nil)
                return
            }
            self.pendingPickerResult = result
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
        guard let callback = pendingPickerResult else {
            return
        }
        pendingPickerResult = nil
        guard let image = info[.originalImage] as? UIImage else {
            callback(nil)
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

        if let pngData = normalizedImage.pngData() ?? normalizedImage.jpegData(compressionQuality: 0.95) {
            callback(FlutterStandardTypedData(bytes: pngData))
        } else {
            callback(nil)
        }
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
        let callback = pendingPickerResult
        pendingPickerResult = nil
        callback?(nil)
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
