cmake_minimum_required(VERSION 3.16)

set(PROJECT_NAME "xue_hua_barcode_scanner")
project(${PROJECT_NAME} LANGUAGES C CXX)

set(PLUGIN_NAME "xue_hua_barcode_scanner_plugin")

add_library(${PLUGIN_NAME} SHARED
  "include/xue_hua_barcode_scanner/xue_hua_barcode_scanner_plugin_c_api.h"
  "xue_hua_barcode_scanner_plugin_c_api.cpp"
)

apply_standard_settings(${PLUGIN_NAME})

# Source contains UTF-8 literals (fallback camera labels). MSVC otherwise
# decodes the file with the system code page (e.g. CP936) and /WX turns C4819
# into C2220. Matches src/CMakeLists.txt.
if(MSVC)
  target_compile_options(${PLUGIN_NAME} PRIVATE /utf-8)
endif()

set_target_properties(${PLUGIN_NAME} PROPERTIES
  CXX_VISIBILITY_PRESET hidden)
target_compile_definitions(${PLUGIN_NAME} PRIVATE FLUTTER_PLUGIN_IMPL)

target_include_directories(${PLUGIN_NAME} INTERFACE
  "${CMAKE_CURRENT_SOURCE_DIR}/include")
target_link_libraries(${PLUGIN_NAME} PRIVATE flutter flutter_wrapper_plugin)

add_subdirectory("${CMAKE_CURRENT_SOURCE_DIR}/../src" "${CMAKE_CURRENT_BINARY_DIR}/shared")

set(xue_hua_barcode_scanner_bundled_libraries
  $<TARGET_FILE:xue_hua_barcode_scanner>
  PARENT_SCOPE
)
