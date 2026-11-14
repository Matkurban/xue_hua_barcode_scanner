import AVFoundation
import CoreMedia
import CoreVideo
import Flutter

#if canImport(xue_hua_barcode_scanner_ffi)
import xue_hua_barcode_scanner_ffi
#endif
#if canImport(xue_hua_barcode_scanner_texture)
import xue_hua_barcode_scanner_texture
#endif

/// Manages the iOS `AVCaptureSession`, video device discovery, hardware torch,
/// `XHScannerTexture` updates, and direct capture-queue FFI frame emission.
final class IOSCameraSessionController: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    private static let pixelFormatLum: Int32 = 0 // C_PIXEL_FORMAT_LUM

    private weak var textureRegistry: FlutterTextureRegistry?

    private let sessionQueue = DispatchQueue(label: "com.kurban.xue_hua_barcode_scanner.session")
    private let videoOutputQueue = DispatchQueue(label: "com.kurban.xue_hua_barcode_scanner.video_output")
    private let frameStateLock = NSLock()

    private var captureSession: AVCaptureSession?
    private var activeDevice: AVCaptureDevice?
    private var textureId: Int64?
    private let scannerTexture = XHScannerTexture()
    private var lastFrameEmitTime: TimeInterval = 0

    private var activeSessionGeneration: UInt64 = 0
    private var frameStreamPaused: Bool = false
    private var cachedTextureId: Int64 = -1

    init(textureRegistry: FlutterTextureRegistry?) {
        self.textureRegistry = textureRegistry
        super.init()
    }

    func unregisterTextureOnDetach() {
        frameStateLock.lock()
        activeSessionGeneration = 0
        cachedTextureId = -1
        frameStateLock.unlock()

        let registry = textureRegistry
        sessionQueue.async {
            self.stopSessionInternal()
            DispatchQueue.main.async {
                if let tid = self.textureId {
                    registry?.unregisterTexture(tid)
                    self.textureId = nil
                }
            }
        }
    }

    func setFrameStreamPaused(_ paused: Bool) {
        frameStateLock.lock()
        frameStreamPaused = paused
        frameStateLock.unlock()
    }

    func listCameras(requestId: Int64) {
        sessionQueue.async { [weak self] in
            guard let self else {
                xh_host_complete_camera_list(requestId, 1, nil, nil, nil, 0)
                return
            }
            let rows = self.cameraRows(devices: self.discoverVideoDevices())
            self.withCStringCameraInfos(rows) { ptr, count in
                xh_host_complete_camera_list(requestId, 1, nil, nil, ptr, count)
            }
        }
    }

    func configureAndStartSession(
        requestId: Int64,
        sessionGeneration: UInt64,
        facing: String,
        cameraId: String?
    ) {
        sessionQueue.async { [weak self] in
            guard let self else {
                xh_host_complete_start_camera(
                    requestId,
                    0,
                    "NO_HOST",
                    "Camera controller was released.",
                    nil,
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
                return
            }
            self.stopSessionInternal()

            var devices = self.discoverVideoDevices()
            guard let selectedDevice = self.selectDevice(
                devices: devices,
                facing: facing,
                cameraId: cameraId
            ) else {
                xh_host_complete_start_camera(
                    requestId,
                    0,
                    "NO_CAMERA",
                    "No camera device found on this iOS device.",
                    nil,
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

                self.frameStateLock.lock()
                self.activeSessionGeneration = sessionGeneration
                self.frameStreamPaused = false
                self.lastFrameEmitTime = 0
                self.frameStateLock.unlock()

                let dimensions = CMVideoFormatDescriptionGetDimensions(device.activeFormat.formatDescription)
                let rawW = Int(dimensions.width > 0 ? dimensions.width : 1280)
                let rawH = Int(dimensions.height > 0 ? dimensions.height : 720)
                let previewW = min(rawW, rawH)
                let previewH = max(rawW, rawH)
                let hasTorch = device.hasTorch && device.isTorchAvailable
                let rows = self.cameraRows(devices: devices)
                let cameraCount = max(rows.count, 1)
                let activeId = device.uniqueID
                let activeFacing = self.facingName(device)

                DispatchQueue.main.async { [weak self] in
                    guard let self else {
                        xh_host_complete_start_camera(
                            requestId,
                            0,
                            "NO_HOST",
                            "Camera controller was released.",
                            nil,
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
                        return
                    }
                    if self.textureId == nil, let registry = self.textureRegistry {
                        self.textureId = registry.register(self.scannerTexture)
                    }
                    let registeredTextureId = self.textureId ?? -1
                    self.frameStateLock.lock()
                    self.cachedTextureId = registeredTextureId
                    self.frameStateLock.unlock()

                    self.withCStringCameraInfos(rows) { ptr, count in
                        xh_host_complete_start_camera(
                            requestId,
                            1,
                            nil,
                            nil,
                            nil,
                            registeredTextureId,
                            hasTorch ? 1 : 0,
                            0,
                            Int32(cameraCount),
                            activeId,
                            activeFacing,
                            Int32(previewW),
                            Int32(previewH),
                            0,
                            ptr,
                            count
                        )
                    }

                    self.sessionQueue.async { [weak self] in
                        guard let self, self.captureSession === session else {
                            return
                        }
                        session.startRunning()
                    }
                }
            } catch {
                self.frameStateLock.lock()
                self.activeSessionGeneration = 0
                self.frameStateLock.unlock()
                xh_host_complete_start_camera(
                    requestId,
                    0,
                    "CAMERA_INIT_FAILED",
                    error.localizedDescription,
                    nil,
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
    }

    func stopCameraSession(requestId: Int64) {
        frameStateLock.lock()
        activeSessionGeneration = 0
        frameStateLock.unlock()

        sessionQueue.async { [weak self] in
            self?.stopSessionInternal()
            if requestId != 0 {
                xh_host_complete_bool(requestId, 1, 1, nil, nil)
            }
        }
    }

    func setTorch(enabled: Bool, requestId: Int64) {
        sessionQueue.async { [weak self] in
            guard let self,
                  let device = self.activeDevice,
                  device.hasTorch,
                  device.isTorchAvailable
            else {
                xh_host_complete_bool(requestId, 1, 0, nil, nil)
                return
            }
            do {
                try device.lockForConfiguration()
                device.torchMode = enabled ? .on : .off
                device.unlockForConfiguration()
                xh_host_complete_bool(requestId, 1, 1, nil, nil)
            } catch {
                xh_host_complete_bool(requestId, 1, 0, nil, nil)
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

        frameStateLock.lock()
        let tid = cachedTextureId
        let generation = activeSessionGeneration
        let paused = frameStreamPaused
        frameStateLock.unlock()

        if tid >= 0 {
            DispatchQueue.main.async { [weak self] in
                self?.textureRegistry?.textureFrameAvailable(tid)
            }
        }

        if generation == 0 || paused {
            return
        }

        let now = CACurrentMediaTime()
        if now - lastFrameEmitTime < 0.14 {
            return
        }
        lastFrameEmitTime = now

        guard let frame = IOSFrameLuminanceExtractor.extractLuminanceFrame(from: pixelBuffer),
              !frame.data.isEmpty
        else {
            return
        }

        frame.data.withUnsafeBytes { rawBuffer in
            guard let base = rawBuffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                return
            }
            xh_host_emit_camera_frame(
                generation,
                base,
                Int32(frame.data.count),
                Int32(frame.width),
                Int32(frame.height),
                Int32(frame.rowStride),
                Self.pixelFormatLum,
                Int32(frame.sensorOrientation)
            )
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

    private func cameraRows(devices: [AVCaptureDevice]) -> [(id: String, label: String, facing: String)] {
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
            return (row.id, label, row.facing)
        }
    }

    private func withCStringCameraInfos(
        _ rows: [(id: String, label: String, facing: String)],
        _ body: (UnsafePointer<XHHostCameraInfo>?, Int32) -> Void
    ) {
        if rows.isEmpty {
            body(nil, 0)
            return
        }
        var infos: [XHHostCameraInfo] = []
        infos.reserveCapacity(rows.count)
        for row in rows {
            infos.append(XHHostCameraInfo(
                id: strdup(row.id),
                label: strdup(row.label),
                facing: strdup(row.facing)
            ))
        }
        defer {
            for info in infos {
                free(info.id)
                free(info.label)
                free(info.facing)
            }
        }
        infos.withUnsafeBufferPointer { buffer in
            body(buffer.baseAddress, Int32(buffer.count))
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
        frameStateLock.lock()
        activeSessionGeneration = 0
        frameStateLock.unlock()

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
