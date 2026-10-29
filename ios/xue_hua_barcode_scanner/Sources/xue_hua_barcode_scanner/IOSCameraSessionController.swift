import AVFoundation
import CoreMedia
import CoreVideo
import Flutter
import xue_hua_barcode_scanner_texture

/// Manages the iOS `AVCaptureSession`, video device discovery, hardware torch,
/// `XHScannerTexture` updates, and throttled frame emission.
final class IOSCameraSessionController: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    private weak var textureRegistry: FlutterTextureRegistry?
    private let eventSinkProvider: () -> FlutterEventSink?

    private let sessionQueue = DispatchQueue(label: "com.kurban.xue_hua_barcode_scanner.session")
    private let videoOutputQueue = DispatchQueue(label: "com.kurban.xue_hua_barcode_scanner.video_output")

    private var captureSession: AVCaptureSession?
    private var activeDevice: AVCaptureDevice?
    private var textureId: Int64?
    private let scannerTexture = XHScannerTexture()
    private var lastFrameEmitTime: TimeInterval = 0

    init(
        textureRegistry: FlutterTextureRegistry?,
        eventSinkProvider: @escaping () -> FlutterEventSink?
    ) {
        self.textureRegistry = textureRegistry
        self.eventSinkProvider = eventSinkProvider
        super.init()
    }

    func unregisterTextureOnDetach() {
        stopCameraSession { [weak self] in
            guard let self else { return }
            DispatchQueue.main.async {
                if let tid = self.textureId {
                    self.textureRegistry?.unregisterTexture(tid)
                    self.textureId = nil
                }
            }
        }
    }

    func listCameras(result: @escaping FlutterResult) {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            let payload = self.cameraPayload(devices: self.discoverVideoDevices())
            DispatchQueue.main.async {
                result(payload)
            }
        }
    }

    func configureAndStartSession(
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

    func stopCameraSession(completion: @escaping () -> Void) {
        sessionQueue.async { [weak self] in
            self?.stopSessionInternal()
            completion()
        }
    }

    func setTorch(enabled: Bool, result: @escaping FlutterResult) {
        sessionQueue.async { [weak self] in
            guard let self,
                  let device = self.activeDevice,
                  device.hasTorch,
                  device.isTorchAvailable
            else {
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

    func captureOutput(
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

        guard eventSinkProvider() != nil else {
            return
        }

        let now = CACurrentMediaTime()
        if now - lastFrameEmitTime < 0.14 {
            return
        }
        lastFrameEmitTime = now

        guard let framePacket = IOSFrameLuminanceExtractor.extractFramePacket(from: pixelBuffer) else {
            return
        }

        DispatchQueue.main.async { [weak self] in
            self?.eventSinkProvider()?(framePacket)
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
}
