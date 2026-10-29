#ifndef XUE_HUA_BARCODE_SCANNER_LINUX_V4L2_ENUMERATOR_H_
#define XUE_HUA_BARCODE_SCANNER_LINUX_V4L2_ENUMERATOR_H_

#include <flutter_linux/flutter_linux.h>

namespace xue_hua_barcode_scanner {

/// Enumerates V4L2 video capture devices under `/sys/class/video4linux` and
/// returns a newly allocated `FlValue*` list of camera maps.
FlValue* ListV4l2VideoDevices();

}  // namespace xue_hua_barcode_scanner

#endif  // XUE_HUA_BARCODE_SCANNER_LINUX_V4L2_ENUMERATOR_H_
