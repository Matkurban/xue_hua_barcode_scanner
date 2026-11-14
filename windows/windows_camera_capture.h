#ifndef XUE_HUA_BARCODE_SCANNER_WINDOWS_CAMERA_CAPTURE_H_
#define XUE_HUA_BARCODE_SCANNER_WINDOWS_CAMERA_CAPTURE_H_

#include "windows_camera_types.h"

#include <flutter/texture_registrar.h>

#include <atomic>
#include <cstdint>
#include <mutex>
#include <string>
#include <thread>
#include <vector>

struct IMFSourceReader;

namespace xue_hua_barcode_scanner {

/// Manages MediaFoundation webcam enumeration, stream capture, RGBA pixel
/// buffer texture updates, and direct capture-thread FFI luminance frame emission.
class WindowsCameraCapture {
 public:
  WindowsCameraCapture(
      flutter::TextureRegistrar* texture_registrar,
      int64_t texture_id);
  ~WindowsCameraCapture();

  const FlutterDesktopPixelBuffer* CopyPixelBuffer();

  std::vector<VideoInput> EnumerateVideoInputs();
  void ListCamerasFfi(int64_t request_id);

  void StartCapture(
      int64_t request_id,
      uint64_t session_generation,
      const std::string& camera_id);

  void StopCapture();
  void SetFrameStreamPaused(bool paused);

 private:
  void CaptureLoop(IMFSourceReader* reader, UINT32 width, UINT32 height);

  flutter::TextureRegistrar* texture_registrar_ = nullptr;
  int64_t texture_id_ = -1;

  std::mutex frame_mutex_;
  std::vector<uint8_t> front_rgba_;
  FlutterDesktopPixelBuffer pixel_buffer_{};

  std::atomic<bool> running_{false};
  std::atomic<uint64_t> active_session_generation_{0};
  std::atomic<bool> frame_stream_paused_{false};
  std::thread capture_thread_;
};

}  // namespace xue_hua_barcode_scanner

#endif  // XUE_HUA_BARCODE_SCANNER_WINDOWS_CAMERA_CAPTURE_H_
