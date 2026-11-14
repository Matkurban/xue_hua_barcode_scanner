// Forwarder Objective-C++ translation unit for macOS Swift Package Manager and CocoaPods builds.
#include "./include/xue_hua_barcode_scanner_ffi/scanner_host_ffi.h"
#include "./include/xue_hua_barcode_scanner_ffi/zxing_ffi_bridge.h"
#include "../../../../src/scanner_host_ffi.cpp"

extern "C" const void* xh_host_retain_apple_ffi_symbols(void) {
  static const void* const kRetainedSymbols[] = {
      reinterpret_cast<const void*>(&zxing_engine_version),
      reinterpret_cast<const void*>(&zxing_decode_image_bytes),
      reinterpret_cast<const void*>(&free_barcode_results),
      reinterpret_cast<const void*>(&zxing_encode_barcode),
      reinterpret_cast<const void*>(&free_encoded_barcode_image),
      reinterpret_cast<const void*>(&xh_host_is_attached),
      reinterpret_cast<const void*>(&xh_host_register_callbacks),
      reinterpret_cast<const void*>(&xh_host_unregister_callbacks),
      reinterpret_cast<const void*>(&xh_host_list_cameras),
      reinterpret_cast<const void*>(&xh_host_start_camera),
      reinterpret_cast<const void*>(&xh_host_stop_camera),
      reinterpret_cast<const void*>(&xh_host_set_torch),
      reinterpret_cast<const void*>(&xh_host_open_app_settings),
      reinterpret_cast<const void*>(&xh_host_pick_image),
      reinterpret_cast<const void*>(&xh_host_set_frame_stream_paused),
      reinterpret_cast<const void*>(&xh_host_free_camera_list_result),
      reinterpret_cast<const void*>(&xh_host_free_start_camera_result),
      reinterpret_cast<const void*>(&xh_host_free_bool_result),
      reinterpret_cast<const void*>(&xh_host_free_pick_image_result),
      reinterpret_cast<const void*>(&xh_host_free_frame_packet),
      reinterpret_cast<const void*>(&xh_host_register_platform),
      reinterpret_cast<const void*>(&xh_host_unregister_platform),
      reinterpret_cast<const void*>(&xh_host_complete_camera_list),
      reinterpret_cast<const void*>(&xh_host_complete_start_camera),
      reinterpret_cast<const void*>(&xh_host_complete_bool),
      reinterpret_cast<const void*>(&xh_host_complete_pick_image),
      reinterpret_cast<const void*>(&xh_host_emit_camera_frame),
  };
  return kRetainedSymbols;
}
