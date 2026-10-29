#ifndef XUE_HUA_BARCODE_SCANNER_WINDOWS_CAMERA_TYPES_H_
#define XUE_HUA_BARCODE_SCANNER_WINDOWS_CAMERA_TYPES_H_

#ifndef NOMINMAX
#define NOMINMAX
#endif
#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif

#include <windows.h>

#include <cstdint>
#include <string>
#include <vector>

namespace xue_hua_barcode_scanner {

// Posted to the top-level Flutter window on the platform thread.
constexpr UINT kDeliverCameraFrameMessage = WM_APP + 0x485;

struct CameraFramePacket {
  std::vector<uint8_t> bytes;
  int32_t width = 0;
  int32_t height = 0;
  int32_t row_stride = 0;
  int32_t format = 0;
  int32_t sensor_orientation = 0;
};

struct VideoInput {
  std::string id;
  std::string label;
};

}  // namespace xue_hua_barcode_scanner

#endif  // XUE_HUA_BARCODE_SCANNER_WINDOWS_CAMERA_TYPES_H_
