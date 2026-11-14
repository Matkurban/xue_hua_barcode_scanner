#ifndef XUE_HUA_BARCODE_SCANNER_WINDOWS_CAMERA_TYPES_H_
#define XUE_HUA_BARCODE_SCANNER_WINDOWS_CAMERA_TYPES_H_

#ifndef NOMINMAX
#define NOMINMAX
#endif
#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif

#include <windows.h>

#include <string>

namespace xue_hua_barcode_scanner {

struct VideoInput {
  std::string id;
  std::string label;
};

}  // namespace xue_hua_barcode_scanner

#endif  // XUE_HUA_BARCODE_SCANNER_WINDOWS_CAMERA_TYPES_H_
