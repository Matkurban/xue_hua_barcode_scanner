#ifndef XUE_HUA_BARCODE_SCANNER_LINUX_V4L2_ENUMERATOR_H_
#define XUE_HUA_BARCODE_SCANNER_LINUX_V4L2_ENUMERATOR_H_

#include <string>
#include <vector>

namespace xue_hua_barcode_scanner {

struct V4l2VideoDevice {
  std::string id;
  std::string label;
  std::string facing;
};

/// Enumerates V4L2 video capture devices under `/sys/class/video4linux`.
std::vector<V4l2VideoDevice> ListV4l2VideoDevices();

}  // namespace xue_hua_barcode_scanner

#endif  // XUE_HUA_BARCODE_SCANNER_LINUX_V4L2_ENUMERATOR_H_
