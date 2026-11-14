#include "linux_v4l2_enumerator.h"

#include <dirent.h>

#include <algorithm>
#include <cstring>
#include <fstream>

namespace xue_hua_barcode_scanner {

std::vector<V4l2VideoDevice> ListV4l2VideoDevices() {
  std::vector<V4l2VideoDevice> devices;
  DIR* dir = opendir("/sys/class/video4linux");
  if (dir == nullptr) {
    return devices;
  }
  std::vector<std::string> names;
  struct dirent* entry = nullptr;
  while ((entry = readdir(dir)) != nullptr) {
    if (std::strncmp(entry->d_name, "video", 5) != 0) {
      continue;
    }
    names.emplace_back(entry->d_name);
  }
  closedir(dir);
  std::sort(names.begin(), names.end());

  devices.reserve(names.size());
  for (const std::string& name : names) {
    const std::string sys_name =
        std::string("/sys/class/video4linux/") + name + "/name";
    std::ifstream input(sys_name);
    std::string label;
    if (input) {
      std::getline(input, label);
      if (!label.empty() && label.back() == '\r') {
        label.pop_back();
      }
    }
    if (label.empty()) {
      label = "摄像头 " + name;
    }
    devices.push_back(V4l2VideoDevice{name, label, "external"});
  }
  return devices;
}

}  // namespace xue_hua_barcode_scanner
