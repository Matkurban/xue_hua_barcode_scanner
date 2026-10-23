# The Flutter tooling requires that developers have CMake 3.10 or later
# installed. You should not increase this version, as doing so will cause
# the plugin to fail to compile for some customers of the plugin.
cmake_minimum_required(VERSION 3.10)

project(xue_hua_barcode_scanner_library VERSION 0.0.1 LANGUAGES C)

add_library(xue_hua_barcode_scanner SHARED
  "xue_hua_barcode_scanner.c"
)

set_target_properties(xue_hua_barcode_scanner PROPERTIES
  PUBLIC_HEADER xue_hua_barcode_scanner.h
  OUTPUT_NAME "xue_hua_barcode_scanner"
)

target_compile_definitions(xue_hua_barcode_scanner PUBLIC DART_SHARED_LIB)

if (ANDROID)
  # Support Android 15 16k page size
  target_link_options(xue_hua_barcode_scanner PRIVATE "-Wl,-z,max-page-size=16384")
endif()
