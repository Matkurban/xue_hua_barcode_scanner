#include "linux_v4l2_enumerator.h"

#include <dirent.h>

#include <algorithm>
#include <cstring>
#include <fstream>
#include <string>
#include <vector>

namespace xue_hua_barcode_scanner {

FlValue* ListV4l2VideoDevices() {
  FlValue* list = fl_value_new_list();
  DIR* dir = opendir("/sys/class/video4linux");
  if (dir == nullptr) {
    return list;
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
  for (const std::string& name : names) {
    const std::string sys_name =
        std::string("/sys/class/video4linux/") + name + "/name";
    std::ifstream input(sys_name);
    std::string label;
    if (input) {
      std::getline(input, label);
    }
    if (label.empty()) {
      label = "摄像头 " + name;
    }
    FlValue* item = fl_value_new_map();
    fl_value_set_string_take(item, "id", fl_value_new_string(name.c_str()));
    fl_value_set_string_take(item, "label", fl_value_new_string(label.c_str()));
    fl_value_set_string_take(item, "facing", fl_value_new_string("external"));
    fl_value_append_take(list, item);
  }
  return list;
}

}  // namespace xue_hua_barcode_scanner
