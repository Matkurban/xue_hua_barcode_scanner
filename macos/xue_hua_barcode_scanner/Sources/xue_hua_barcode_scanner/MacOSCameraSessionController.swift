import AVFoundation
import CoreMedia
import CoreVideo
import FlutterMacOS

#if canImport(xue_hua_barcode_scanner_ffi)
import xue_hua_barcode_scanner_ffi
#endif

/// Manages the macOS `AVCaptureSession`, video device discovery (including Continuity Camera
/// and external USB webcams), `FlutterTexture` pixel buffer retention, and direct FFI frame emission.
final class MacOSCameraSessionController: NSObject,
    FlutterTexture,
    AVCaptureVideoDataOutputSampleBufferDelegate
{
    private static let pixelFormatLum: Int32 = 0 // C_PIXEL_FORMAT_LUM

    private weak var textureRegistry: FlutterTextureRegistry?

    private let sessionQueue = DispatchQueue(label: "com.kurban.xue_hua_barcode_scanner.macos.session")
    private let videoOutputQueue = DispatchQueue(label: "com.kurban.xue_hua_barcode_scanner.macos.video_output")
    private let pixelBufferLock = NSLock()
    private let frameStateLock = NSLock()

    private var captureSession: AVCaptureSession?
    private var activeDevice: AVCaptureDevice?
    private var currentDeviceIndex: Int = 0
    private var textureId: Int64?
    private var latestPixelBuffer: CVPixelBuffer?
    private var lastFrameEmitTime: TimeInterval = 0

    private var activeSessionGeneration: UInt64 = 0
    private var frameStreamPaused: Bool = false
    private var cachedTextureId: Int64 = -1

    init(textureRegistry: FlutterTextureRegistry?) {
        self.textureRegistry = textureRegistry
        super.init()
    }

    func copyPixelBuffer() -> Unmanaged<CVPixelBuffer>? {
        pixelBufferLock.lock()
        defer { pixelBufferLock.unlock() }
        guard let buffer = latestPixelBuffer else {
            return nil
        }
        return Unmanaged.passRetained(buffer)
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

            let devices = self.discoverVideoDevices()
            guard !devices.isEmpty else {
                xh_host_complete_start_camera(
                    requestId,
                    0,
                    "NO_CAMERA",
                    "No camera device found on this Mac.",
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

                self.frameStateLock.lock()
                self.activeSessionGeneration = sessionGeneration
                self.frameStreamPaused = false
                self.lastFrameEmitTime = 0
                self.frameStateLock.unlock()

                let dimensions = CMVideoFormatDescriptionGetDimensions(device.activeFormat.formatDescription)
                let previewW = Int(dimensions.width > 0 ? dimensions.width : 1280)
                let previewH = Int(dimensions.height > 0 ? dimensions.height : 720)
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
                        self.textureId = registry.register(self)
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
                            0,
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

    func captureOutput(
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

        guard let frame = MacOSFrameLuminanceExtractor.extractLuminanceFrame(from: pixelBuffer),
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
            let base = device.localizedName.isEmpty ? "摄像头" : device.localizedName
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

    private func stopSessionInternal() {
        frameStateLock.lock()
        activeSessionGeneration = 0
        frameStateLock.unlock()

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
}
