// Public C header forwarder for Swift Package Manager and CocoaPods on macOS.
#ifndef XUE_HUA_BARCODE_SCANNER_MACOS_HOST_PUBLIC_HEADER_H_
#define XUE_HUA_BARCODE_SCANNER_MACOS_HOST_PUBLIC_HEADER_H_

#include "../../../../../../src/scanner_host_ffi.h"

#ifdef __cplusplus
extern "C" {
#endif

/// Forces the macOS static/dynamic linker to keep all FFI symbols referenced
/// by Dart `DynamicLibrary.process()`.
XH_HOST_EXPORT const void* xh_host_retain_apple_ffi_symbols(void);

#ifdef __cplusplus
}
#endif

#endif  // XUE_HUA_BARCODE_SCANNER_MACOS_HOST_PUBLIC_HEADER_H_
