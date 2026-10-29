import AVFoundation
import CoreMedia
import CoreVideo
import Flutter
import xue_hua_barcode_scanner_texture
import UIKit

#if canImport(xue_hua_barcode_scanner_ffi)
import xue_hua_barcode_scanner_ffi
#endif

public final class XueHuaBarcodeScannerPlugin: NSObject,
    FlutterPlugin,
    FlutterStreamHandler,
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

    private var captureSession: AVCaptureSession?
    private var activeDevice: AVCaptureDevice?
    private var textureId: Int64?
    private let scannerTexture = XHScannerTexture()
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

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "listCameras":
            listCameras(result: result)
        case "startCamera":
            let args = call.arguments as? [String: Any]
            let facing = (args?["facing"] as? String) ?? "back"
            let cameraId = args?["cameraId"] as? String
            startCamera(facing: facing, cameraId: cameraId, result: result)
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
        case "openAppSettings":
            openAppPermissionSettings(result: result)
        case "pickImageFromGallery":
            pickImageFromGallery(result: result)
        case "pickImageFilePath":
            result(nil)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func openAppPermissionSettings(result: @escaping FlutterResult) {
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

    private func listCameras(result: @escaping FlutterResult) {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            let payload = self.cameraPayload(devices: self.discoverVideoDevices())
            DispatchQueue.main.async {
                result(payload)
            }
        }
    }

    private func discoverVideoDevices() -> [AVCaptureDevice] {
        var types: [AVCaptureDevice.DeviceType] = [
            .builtInWideAngleCamera,
            .builtInTelephotoCamera,
        ]
        if #available(iOS 13.0, *) {
            types.append(.builtInUltraWideCamera)
        }
        if #available(iOS 17.0, *) {
            types.append(.external)
        }
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: types,
            mediaType: .video,
            position: .unspecified
        )
        return discovery.devices
    }

    private func facingName(_ device: AVCaptureDevice) -> String {
        switch device.position {
        case .front:
            return "front"
        case .back:
            return "back"
        default:
            return "external"
        }
    }

    private func cameraPayload(devices: [AVCaptureDevice]) -> [[String: String]] {
        var counts: [String: Int] = [:]
        var rows: [(id: String, facing: String, base: String)] = []
        for device in devices {
            let facing = facingName(device)
            let base = device.localizedName.isEmpty ? facing : device.localizedName
            rows.append((device.uniqueID, facing, base))
            counts[base, default: 0] += 1
        }
        var seen: [String: Int] = [:]
        return rows.map { row in
            let next = (seen[row.base] ?? 0) + 1
            seen[row.base] = next
            let label = (counts[row.base] ?? 1) > 1 ? "\(row.base) \(next)" : row.base
            return ["id": row.id, "label": label, "facing": row.facing]
        }
    }

    private func selectDevice(
        devices: [AVCaptureDevice],
        facing: String,
        cameraId: String?
    ) -> AVCaptureDevice? {
        if let cameraId, !cameraId.isEmpty,
           let match = devices.first(where: { $0.uniqueID == cameraId }) {
            return match
        }
        if facing == "front" {
            return devices.first(where: {
                $0.position == .front && $0.deviceType == .builtInWideAngleCamera
            }) ?? devices.first(where: { $0.position == .front })
                ?? AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
        }
        if facing == "external" {
            return devices.first(where: { $0.position == .unspecified }) ?? devices.first
        }
        return devices.first(where: {
            $0.position == .back && $0.deviceType == .builtInWideAngleCamera
        }) ?? devices.first(where: { $0.position == .back })
            ?? AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
            ?? devices.first
            ?? AVCaptureDevice.default(for: .video)
    }

    private func startCamera(facing: String, cameraId: String?, result: @escaping FlutterResult) {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            configureAndStartSession(facing: facing, cameraId: cameraId, result: result)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                guard let self else { return }
                if granted {
                    self.configureAndStartSession(facing: facing, cameraId: cameraId, result: result)
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

    private func configureAndStartSession(
        facing: String,
        cameraId: String?,
        result: @escaping FlutterResult
    ) {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.stopSessionInternal()

            var devices = self.discoverVideoDevices()
            guard let selectedDevice = self.selectDevice(
                devices: devices,
                facing: facing,
                cameraId: cameraId
            ) else {
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

            if !devices.contains(where: { $0.uniqueID == selectedDevice.uniqueID }) {
                devices.append(selectedDevice)
            }
            let device = selectedDevice

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

                let dimensions = CMVideoFormatDescriptionGetDimensions(device.activeFormat.formatDescription)
                let rawW = Int(dimensions.width > 0 ? dimensions.width : 1280)
                let rawH = Int(dimensions.height > 0 ? dimensions.height : 720)
                let previewW = min(rawW, rawH)
                let previewH = max(rawW, rawH)
                let hasTorch = device.hasTorch && device.isTorchAvailable
                let payload = self.cameraPayload(devices: devices)
                let cameraCount = max(payload.count, 1)

                DispatchQueue.main.async {
                    if self.textureId == nil, let registry = self.textureRegistry {
                        self.textureId = registry.register(self.scannerTexture)
                    }
                    result([
                        "textureId": self.textureId as Any,
                        "hasTorch": hasTorch,
                        "availableCameraCount": cameraCount,
                        "cameras": payload,
                        "activeCameraId": device.uniqueID,
                        "cameraFacing": self.facingName(device),
                        "previewWidth": previewW,
                        "previewHeight": previewH,
                        "sensorOrientation": 0
                    ])
                }
                session.startRunning()
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
        scannerTexture.clearPixelBuffer()
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

        scannerTexture.update(pixelBuffer)

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
        let pixelCount = width * height
        guard width > 0, height > 0, bytesPerRow >= width * 4 else {
            return
        }

        // Extract compact 1-channel luminance (Y) on the background video queue
        // to cut main-thread EventChannel payload size by 75%.
        var lumaData = Data(count: pixelCount)
        let srcPtr = baseAddress.assumingMemoryBound(to: UInt8.self)
        lumaData.withUnsafeMutableBytes { rawBuffer in
            guard let dstPtr = rawBuffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                return
            }
            for row in 0..<height {
                let srcRow = srcPtr.advanced(by: row * bytesPerRow)
                let dstRow = dstPtr.advanced(by: row * width)
                for col in 0..<width {
                    let px = srcRow.advanced(by: col * 4)
                    let b = UInt16(px[0])
                    let g = UInt16(px[1])
                    let r = UInt16(px[2])
                    dstRow[col] = UInt8((r * 77 + g * 150 + b * 29) >> 8)
                }
            }
        }

        let framePacket: [String: Any] = [
            "bytes": FlutterStandardTypedData(bytes: lumaData),
            "width": width,
            "height": height,
            "rowStride": width,
            "format": 0,
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
