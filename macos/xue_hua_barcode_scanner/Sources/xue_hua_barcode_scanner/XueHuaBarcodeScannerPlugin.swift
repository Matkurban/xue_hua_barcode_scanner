import AppKit
import AVFoundation
import CoreMedia
import CoreVideo
import FlutterMacOS
import UniformTypeIdentifiers

#if canImport(xue_hua_barcode_scanner_ffi)
import xue_hua_barcode_scanner_ffi
#endif

public final class XueHuaBarcodeScannerPlugin: NSObject,
    FlutterPlugin,
    FlutterStreamHandler,
    FlutterTexture,
    AVCaptureVideoDataOutputSampleBufferDelegate
{
    private var textureRegistry: FlutterTextureRegistry?
    private var methodChannel: FlutterMethodChannel?
    private var eventChannel: FlutterEventChannel?
    private var eventSink: FlutterEventSink?

    private let sessionQueue = DispatchQueue(label: "com.kurban.xue_hua_barcode_scanner.macos.session")
    private let videoOutputQueue = DispatchQueue(label: "com.kurban.xue_hua_barcode_scanner.macos.video_output")
    private let pixelBufferLock = NSLock()

    private var captureSession: AVCaptureSession?
    private var activeDevice: AVCaptureDevice?
    private var currentDeviceIndex: Int = 0
    private var textureId: Int64?
    private var latestPixelBuffer: CVPixelBuffer?
    private var lastFrameEmitTime: TimeInterval = 0

    public static func register(with registrar: FlutterPluginRegistrar) {
        #if canImport(xue_hua_barcode_scanner_ffi)
        _ = zxing_engine_version()
        free_barcode_results(zxing_decode_image_bytes(nil, 0, 0, 0, 0, 0, 0, 0))
        free_encoded_barcode_image(zxing_encode_barcode(nil, 0, 0, 0, 0))
        #endif

        let instance = XueHuaBarcodeScannerPlugin()
        instance.textureRegistry = registrar.textures

        let methodChannel = FlutterMethodChannel(
            name: "com.kurban.xue_hua_barcode_scanner/methods",
            binaryMessenger: registrar.messenger
        )
        instance.methodChannel = methodChannel
        registrar.addMethodCallDelegate(instance, channel: methodChannel)

        let eventChannel = FlutterEventChannel(
            name: "com.kurban.xue_hua_barcode_scanner/frames",
            binaryMessenger: registrar.messenger
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
        case "listCameras":
            listCameras(result: result)
        case "startCamera":
            let args = call.arguments as? [String: Any]
            let facing = (args?["facing"] as? String) ?? "front"
            let cameraId = args?["cameraId"] as? String
            startCamera(facing: facing, cameraId: cameraId, result: result)
        case "stopCamera":
            stopCameraSession {
                DispatchQueue.main.async {
                    result(nil)
                }
            }
        case "setTorch":
            result(false)
        case "pickImageFromGallery":
            pickImageFromDisk(result: result)
        case "pickImageFilePath":
            result(nil)
        default:
            result(FlutterMethodNotImplemented)
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
            let base = device.localizedName.isEmpty ? "摄像头" : device.localizedName
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
                    message: "Camera access is not authorized. Please enable camera access in System Settings > Privacy & Security > Camera.",
                    details: nil
                )
            )
        }
    }

    private func discoverVideoDevices() -> [AVCaptureDevice] {
        var types: [AVCaptureDevice.DeviceType] = [.builtInWideAngleCamera]
        if #available(macOS 14.0, *) {
            types.append(.external)
            types.append(.continuityCamera)
        } else {
            types.append(.externalUnknown)
        }
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: types,
            mediaType: .video,
            position: .unspecified
        )
        if !discovery.devices.isEmpty {
            return discovery.devices
        }
        if let fallback = AVCaptureDevice.default(for: .video) {
            return [fallback]
        }
        return []
    }

    private func configureAndStartSession(
        facing: String,
        cameraId: String?,
        result: @escaping FlutterResult
    ) {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.stopSessionInternal()

            let devices = self.discoverVideoDevices()
            guard !devices.isEmpty else {
                DispatchQueue.main.async {
                    result(
                        FlutterError(
                            code: "NO_CAMERA",
                            message: "No camera device found on this Mac.",
                            details: nil
                        )
                    )
                }
                return
            }

            let device: AVCaptureDevice
            if let cameraId, !cameraId.isEmpty,
               let match = devices.first(where: { $0.uniqueID == cameraId }) {
                device = match
            } else if facing == "external", devices.count > 1 {
                device = devices.last ?? devices[0]
            } else {
                device = devices[0]
            }
            if let index = devices.firstIndex(where: { $0.uniqueID == device.uniqueID }) {
                self.currentDeviceIndex = index
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

                session.commitConfiguration()
                self.captureSession = session
                self.activeDevice = device

                let dimensions = CMVideoFormatDescriptionGetDimensions(device.activeFormat.formatDescription)
                let previewW = Int(dimensions.width > 0 ? dimensions.width : 1280)
                let previewH = Int(dimensions.height > 0 ? dimensions.height : 720)
                let payload = self.cameraPayload(devices: devices)
                let cameraCount = max(payload.count, 1)

                // Return before startRunning so a hung capture session cannot
                // block the Dart start() future indefinitely.
                DispatchQueue.main.async {
                    if self.textureId == nil, let registry = self.textureRegistry {
                        self.textureId = registry.register(self)
                    }
                    result([
                        "textureId": self.textureId as Any,
                        "hasTorch": false,
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

    private func pickImageFromDisk(result: @escaping FlutterResult) {
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
            guard response == .OK, let url = panel.url, let data = try? Data(contentsOf: url) else {
                result(nil)
                return
            }
            result(FlutterStandardTypedData(bytes: data))
        }
    }
}
