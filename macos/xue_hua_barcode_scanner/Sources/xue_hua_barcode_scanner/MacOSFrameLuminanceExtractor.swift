import CoreVideo
import FlutterMacOS
import Foundation

/// Extracts compact 1-channel 8-bit luminance (`PixelFormat.lum`) buffers from
/// macOS `CVPixelBuffer` (`kCVPixelFormatType_32BGRA`) frames on the background queue.
enum MacOSFrameLuminanceExtractor {
    static func extractFramePacket(from pixelBuffer: CVPixelBuffer) -> [String: Any]? {
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else {
            return nil
        }
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let pixelCount = width * height
        guard width > 0, height > 0, bytesPerRow >= width * 4 else {
            return nil
        }

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

        return [
            "bytes": FlutterStandardTypedData(bytes: lumaData),
            "width": width,
            "height": height,
            "rowStride": width,
            "format": 0,
            "sensorOrientation": 0
        ]
    }
}
