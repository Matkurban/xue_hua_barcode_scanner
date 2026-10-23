import AVFoundation
import CoreMedia
import CoreVideo
import Flutter
import UIKit

#if canImport(xue_hua_barcode_scanner_ffi)
import xue_hua_barcode_scanner_ffi
#endif

public final class XueHuaBarcodeScannerPlugin: NSObject,
    FlutterPlugin,
    FlutterStreamHandler,
    FlutterTexture,
    AVCaptureVideoDataOutputSampleBufferDelegate,
    UIImagePickerControllerDelegate,
    UINavigationControllerDelegate
{
    private var textureRegistry: FlutterTextureRegistry?
    private var methodChannel: FlutterMethodChannel?
    private var eventChannel: FlutterEventChannel?
    private var eventSink: FlutterEventSink?

    private let sessionQueue = DispatchQueue(label: "com.kurban.xue_hua_barcode_scanner.session")
    private let videoOutputQueue = DispatchQueue(label: "com.kurban.xue_hua_barcode_scanner.video_output")
    private let pixelBufferLock = NSLock()

    private var captureSession: AVCaptureSession?
    private var activeDevice: AVCaptureDevice?
    private var textureId: Int64?
    private var latestPixelBuffer: CVPixelBuffer?
    private var lastFrameEmitTime: TimeInterval = 0
    private var pendingPickerResult: FlutterResult?

    public static func register(with registrar: FlutterPluginRegistrar) {
        #if canImport(xue_hua_barcode_scanner_ffi)
        _ = zxing_engine_version()
        free_barcode_results(zxing_decode_image_bytes(nil, 0, 0, 0, 0, 0, 0, 0))
        free_encoded_barcode_image(zxing_encode_barcode(nil, 0, 0, 0, 0))
        #endif

        let instance = XueHuaBarcodeScannerPlugin()
        instance.textureRegistry = registrar.textures()

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
        stopCameraSession { [weak self] in
            guard let self else { return }
            DispatchQueue.main.async {
                if let tid = self.textureId {
                    self.textureRegistry?.unregisterTexture(tid)
                    self.textureId = nil
                }
            }
        }
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

    public func copyPixelBuffer() -> Unmanaged<CVPixelBuffer>? {
        pixelBufferLock.lock()
        defer { pixelBufferLock.unlock() }
        guard let buffer = latestPixelBuffer else {
            return nil
        }
        return Unmanaged.passRetained(buffer)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "startCamera":
            let args = call.arguments as? [String: Any]
            let facing = (args?["facing"] as? String) ?? "back"
            startCamera(facing: facing, result: result)
        case "stopCamera":
            stopCameraSession {
                DispatchQueue.main.async {
                    result(nil)
                }
            }
        case "setTorch":
            let args = call.arguments as? [String: Any]
            let enabled = (args?["enabled"] as? Bool) ?? false
            setTorch(enabled: enabled, result: result)
        case "pickImageFromGallery":
            pickImageFromGallery(result: result)
        case "pickImageFilePath":
            result(nil)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func startCamera(facing: String, result: @escaping FlutterResult) {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            configureAndStartSession(facing: facing, result: result)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                guard let self else { return }
                if granted {
                    self.configureAndStartSession(facing: facing, result: result)
                } else {
                    DispatchQueue.main.async {
                        result(
                            FlutterError(
                                code: "CAMERA_PERMISSION_DENIED",
                                message: "Camera permission was denied by the user.",
                                details: nil
                            )
                        )
                    }
                }
            }
        default:
            result(
                FlutterError(
                    code: "CAMERA_PERMISSION_DENIED",
                    message: "Camera access is not authorized. Please enable camera access in Settings.",
                    details: nil
                )
            )
        }
    }

    private func configureAndStartSession(facing: String, result: @escaping FlutterResult) {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.stopSessionInternal()

            let discovery = AVCaptureDevice.DiscoverySession(
                deviceTypes: [.builtInWideAngleCamera],
                mediaType: .video,
                position: .unspecified
            )
            let devices = discovery.devices
            let targetPosition: AVCaptureDevice.Position = (facing == "front") ? .front : .back
            let selectedDevice =
                devices.first(where: { $0.position == targetPosition }) ??
                AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: targetPosition) ??
                devices.first ??
                AVCaptureDevice.default(for: .video)

            guard let device = selectedDevice else {
                DispatchQueue.main.async {
                    result(
                        FlutterError(
                            code: "NO_CAMERA",
                            message: "No camera device found on this iOS device.",
                            details: nil
                        )
                    )
                }
                return
            }

            do {
                let input = try AVCaptureDeviceInput(device: device)
                let session = AVCaptureSession()
                session.beginConfiguration()
                if session.canSetSessionPreset(.hd1280x720) {
                    session.sessionPreset = .hd1280x720
                } else if session.canSetSessionPreset(.high) {
                    session.sessionPreset = .high
                }

                if session.canAddInput(input) {
                    session.addInput(input)
                }

                let output = AVCaptureVideoDataOutput()
                output.alwaysDiscardsLateVideoFrames = true
                output.videoSettings = [
                    kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
                ]
                output.setSampleBufferDelegate(self, queue: self.videoOutputQueue)

                if session.canAddOutput(output) {
                    session.addOutput(output)
                }

                if let connection = output.connection(with: .video) {
                    if connection.isVideoOrientationSupported {
                        connection.videoOrientation = .portrait
                    }
                    if connection.isVideoMirroringSupported {
                        connection.isVideoMirrored = (device.position == .front)
                    }
                }

                session.commitConfiguration()

                if device.isFocusModeSupported(.continuousAutoFocus) {
                    try? device.lockForConfiguration()
                    device.focusMode = .continuousAutoFocus
                    device.unlockForConfiguration()
                }

                self.captureSession = session
                self.activeDevice = device
                session.startRunning()

                let dimensions = CMVideoFormatDescriptionGetDimensions(device.activeFormat.formatDescription)
                let rawW = Int(dimensions.width > 0 ? dimensions.width : 1280)
                let rawH = Int(dimensions.height > 0 ? dimensions.height : 720)
                let previewW = min(rawW, rawH)
                let previewH = max(rawW, rawH)
                let hasTorch = device.hasTorch && device.isTorchAvailable
                let cameraCount = max(devices.count, 1)

                DispatchQueue.main.async {
                    if self.textureId == nil, let registry = self.textureRegistry {
                        self.textureId = registry.register(self)
                    }
                    result([
                        "textureId": self.textureId as Any,
                        "hasTorch": hasTorch,
                        "availableCameraCount": cameraCount,
                        "previewWidth": previewW,
                        "previewHeight": previewH,
                        "sensorOrientation": 0
                    ])
                }
            } catch {
                DispatchQueue.main.async {
                    result(
                        FlutterError(
                            code: "CAMERA_INIT_FAILED",
                            message: error.localizedDescription,
                            details: nil
                        )
                    )
                }
            }
        }
    }

    private func stopCameraSession(completion: @escaping () -> Void) {
        sessionQueue.async { [weak self] in
            self?.stopSessionInternal()
            completion()
        }
    }

    private func stopSessionInternal() {
        if let device = activeDevice, device.hasTorch, device.torchMode != .off {
            try? device.lockForConfiguration()
            device.torchMode = .off
            device.unlockForConfiguration()
        }
        if let session = captureSession {
            if session.isRunning {
                session.stopRunning()
            }
            for input in session.inputs {
                session.removeInput(input)
            }
            for output in session.outputs {
                session.removeOutput(output)
            }
        }
        captureSession = nil
        activeDevice = nil
        pixelBufferLock.lock()
        latestPixelBuffer = nil
        pixelBufferLock.unlock()
    }

    private func setTorch(enabled: Bool, result: @escaping FlutterResult) {
        sessionQueue.async { [weak self] in
            guard let self, let device = self.activeDevice, device.hasTorch, device.isTorchAvailable else {
                DispatchQueue.main.async {
                    result(false)
                }
                return
            }
            do {
                try device.lockForConfiguration()
                device.torchMode = enabled ? .on : .off
                device.unlockForConfiguration()
                DispatchQueue.main.async {
                    result(true)
                }
            } catch {
                DispatchQueue.main.async {
                    result(false)
                }
            }
        }
    }

    public func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }

        pixelBufferLock.lock()
        latestPixelBuffer = pixelBuffer
        pixelBufferLock.unlock()

        if let tid = textureId {
            DispatchQueue.main.async { [weak self] in
                self?.textureRegistry?.textureFrameAvailable(tid)
            }
        }

        guard eventSink != nil else {
            return
        }

        let now = CACurrentMediaTime()
        if now - lastFrameEmitTime < 0.14 {
            return
        }
        lastFrameEmitTime = now

        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else {
            return
        }
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let byteCount = bytesPerRow * height
        guard width > 0, height > 0, byteCount > 0 else {
            return
        }

        let data = Data(bytes: baseAddress, count: byteCount)
        let framePacket: [String: Any] = [
            "bytes": FlutterStandardTypedData(bytes: data),
            "width": width,
            "height": height,
            "rowStride": bytesPerRow,
            "format": 2,
            "sensorOrientation": 0
        ]

        DispatchQueue.main.async { [weak self] in
            self?.eventSink?(framePacket)
        }
    }

    private func pickImageFromGallery(result: @escaping FlutterResult) {
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

    public func imagePickerController(
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

    public func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
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
