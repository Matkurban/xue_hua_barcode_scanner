# Root CMakeLists.txt for xue_hua_barcode_scanner
# Author: Matkurban <3496354336@qq.com>
# Repository: https://github.com/Matkurban/xue_hua_barcode_scanner
cmake_minimum_required(VERSION 3.16)

project(xue_hua_barcode_scanner_root VERSION 1.0.0 LANGUAGES C CXX)

add_subdirectory("${CMAKE_CURRENT_SOURCE_DIR}/src" "${CMAKE_CURRENT_BINARY_DIR}/src")
