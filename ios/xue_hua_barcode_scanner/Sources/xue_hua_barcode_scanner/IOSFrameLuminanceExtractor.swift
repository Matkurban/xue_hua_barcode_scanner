import CoreVideo
import Foundation

/// Compact 1-channel 8-bit luminance buffer extracted from an iOS `CVPixelBuffer`.
struct IOSLuminanceFrame {
    let data: Data
    let width: Int
    let height: Int
    let rowStride: Int
    let sensorOrientation: Int
}

/// Extracts compact 1-channel 8-bit luminance (`C_PIXEL_FORMAT_LUM`) buffers from
/// iOS `CVPixelBuffer` (`kCVPixelFormatType_32BGRA`) frames on the video output queue.
enum IOSFrameLuminanceExtractor {
    static func extractLuminanceFrame(from pixelBuffer: CVPixelBuffer) -> IOSLuminanceFrame? {
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

        return IOSLuminanceFrame(
            data: lumaData,
            width: width,
            height: height,
            rowStride: width,
            sensorOrientation: 0
        )
    }
}
