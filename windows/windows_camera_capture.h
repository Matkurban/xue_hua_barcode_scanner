#ifndef XUE_HUA_BARCODE_SCANNER_WINDOWS_CAMERA_CAPTURE_H_
#define XUE_HUA_BARCODE_SCANNER_WINDOWS_CAMERA_CAPTURE_H_

#include "windows_camera_types.h"

#include <flutter/encodable_value.h>
#include <flutter/method_result.h>
#include <flutter/texture_registrar.h>

#include <atomic>
#include <cstdint>
#include <functional>
#include <mutex>
#include <string>
#include <thread>
#include <vector>

struct IMFSourceReader;

namespace xue_hua_barcode_scanner {

/// Manages MediaFoundation webcam enumeration, stream capture, RGBA pixel
/// buffer texture updates, and 1-channel luminance frame emission.
class WindowsCameraCapture {
 public:
  using FrameReadyCallback = std::function<void(CameraFramePacket)>;

  WindowsCameraCapture(
      flutter::TextureRegistrar* texture_registrar,
      int64_t texture_id,
      FrameReadyCallback on_frame_ready);
  ~WindowsCameraCapture();

  const FlutterDesktopPixelBuffer* CopyPixelBuffer();

  std::vector<VideoInput> EnumerateVideoInputs();
  static flutter::EncodableList CameraListValue(
      const std::vector<VideoInput>& inputs);

  void StartCapture(
      const std::string& camera_id,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  void StopCapture();

 private:
  void CaptureLoop(IMFSourceReader* reader, UINT32 width, UINT32 height);

  flutter::TextureRegistrar* texture_registrar_ = nullptr;
  int64_t texture_id_ = -1;
  FrameReadyCallback on_frame_ready_;

  std::mutex frame_mutex_;
  std::vector<uint8_t> front_rgba_;
  FlutterDesktopPixelBuffer pixel_buffer_{};

  std::atomic<bool> running_{false};
  std::thread capture_thread_;
};

}  // namespace xue_hua_barcode_scanner

#endif  // XUE_HUA_BARCODE_SCANNER_WINDOWS_CAMERA_CAPTURE_H_
