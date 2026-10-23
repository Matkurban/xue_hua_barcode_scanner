# CMakeLists.txt for xue_hua_barcode_scanner (Android, Windows, Linux)
# Author: Matkurban <3496354336@qq.com>
# Repository: https://github.com/Matkurban/xue_hua_barcode_scanner
cmake_minimum_required(VERSION 3.16)

project(xue_hua_barcode_scanner_library VERSION 1.0.0 LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

include(FetchContent)

# Option to automatically fetch official zxing-cpp v2.2.1 via CMake FetchContent
option(XH_FETCH_ZXING_CPP "Fetch official zxing-cpp v2.2.1 via FetchContent" ON)

if(XH_FETCH_ZXING_CPP)
  set(ZXING_EXAMPLES OFF CACHE BOOL "Disable zxing-cpp examples" FORCE)
  set(ZXING_UNIT_TESTS OFF CACHE BOOL "Disable zxing-cpp unit tests" FORCE)
  set(ZXING_BLACKBOX_TESTS OFF CACHE BOOL "Disable zxing-cpp blackbox tests" FORCE)
  set(ZXING_WRITERS ON CACHE BOOL "Enable zxing-cpp barcode writers" FORCE)
  set(ZXING_READERS ON CACHE BOOL "Enable zxing-cpp barcode readers" FORCE)
  set(ZXING_EXPERIMENTAL_API OFF CACHE BOOL "Disable experimental API" FORCE)
  set(BUILD_SHARED_LIBS OFF CACHE BOOL "Build ZXing as a static library linked into FFI plugin" FORCE)

  FetchContent_Declare(
    zxing_cpp
    GIT_REPOSITORY https://github.com/zxing-cpp/zxing-cpp.git
    GIT_TAG        v2.2.1
    GIT_SHALLOW    TRUE
  )
  FetchContent_MakeAvailable(zxing_cpp)
endif()

add_library(xue_hua_barcode_scanner SHARED
  "zxing_ffi_bridge.cpp"
)

set_target_properties(xue_hua_barcode_scanner PROPERTIES
  PUBLIC_HEADER zxing_ffi_bridge.h
  OUTPUT_NAME "xue_hua_barcode_scanner"
  VERSION 1.0.0
  SOVERSION 1
)

target_compile_definitions(xue_hua_barcode_scanner PUBLIC DART_SHARED_LIB)

if(TARGET ZXing::ZXing)
  target_link_libraries(xue_hua_barcode_scanner PRIVATE ZXing::ZXing)
elseif(TARGET ZXing)
  target_link_libraries(xue_hua_barcode_scanner PRIVATE ZXing)
endif()

if(MSVC)
  target_compile_options(xue_hua_barcode_scanner PRIVATE /W4 /EHsc /utf-8)
else()
  target_compile_options(xue_hua_barcode_scanner PRIVATE -Wall -Wextra -O3 -fvisibility=default)
endif()

if(ANDROID)
  # Support Android 15+ 16 KB page alignment
  target_link_options(xue_hua_barcode_scanner PRIVATE "-Wl,-z,max-page-size=16384")
endif()
