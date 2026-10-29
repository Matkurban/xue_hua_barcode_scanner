cmake_minimum_required(VERSION 3.16)

set(PROJECT_NAME "xue_hua_barcode_scanner")
project(${PROJECT_NAME} LANGUAGES C CXX)

set(PLUGIN_NAME "xue_hua_barcode_scanner_plugin")

add_library(${PLUGIN_NAME} SHARED
  "xue_hua_barcode_scanner_plugin.cc"
  "linux_v4l2_enumerator.h"
  "linux_v4l2_enumerator.cc"
  "linux_file_chooser.h"
  "linux_file_chooser.cc"
)

apply_standard_settings(${PLUGIN_NAME})

set_target_properties(${PLUGIN_NAME} PROPERTIES
  CXX_VISIBILITY_PRESET hidden)
target_compile_definitions(${PLUGIN_NAME} PRIVATE FLUTTER_PLUGIN_IMPL)

target_include_directories(${PLUGIN_NAME} INTERFACE
  "${CMAKE_CURRENT_SOURCE_DIR}/include")
target_link_libraries(${PLUGIN_NAME} PRIVATE flutter)
target_link_libraries(${PLUGIN_NAME} PRIVATE PkgConfig::GTK)

add_subdirectory("${CMAKE_CURRENT_SOURCE_DIR}/../src" "${CMAKE_CURRENT_BINARY_DIR}/shared")

set(xue_hua_barcode_scanner_bundled_libraries
  $<TARGET_FILE:xue_hua_barcode_scanner>
  PARENT_SCOPE
)
