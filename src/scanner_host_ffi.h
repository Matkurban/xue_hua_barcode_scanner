#ifndef XUE_HUA_BARCODE_SCANNER_SCANNER_HOST_FFI_H_
#define XUE_HUA_BARCODE_SCANNER_SCANNER_HOST_FFI_H_

#include <stdint.h>

#if defined(_WIN32) || defined(_WIN64)
#if defined(XH_HOST_BUILD_DLL)
#define XH_HOST_EXPORT __declspec(dllexport)
#elif defined(XH_HOST_USE_DLL)
#define XH_HOST_EXPORT __declspec(dllimport)
#else
#define XH_HOST_EXPORT
#endif
#else
#define XH_HOST_EXPORT __attribute__((visibility("default"))) __attribute__((used))
#endif

#ifdef __cplusplus
extern "C" {
#endif

/// Describes one camera or video input source reported by a native host.
typedef struct XHHostCameraInfo {
  char* id;
  char* label;
  char* facing;
} XHHostCameraInfo;

/// Heap-allocated result for an asynchronous `listCameras` request.
/// Must be freed via `xh_host_free_camera_list_result`.
typedef struct XHHostCameraListResult {
  int64_t request_id;
  int32_t ok;
  char* error_code;
  char* error_message;
  XHHostCameraInfo* cameras;
  int32_t camera_count;
} XHHostCameraListResult;

/// Heap-allocated result for an asynchronous `startCamera` request.
/// Must be freed via `xh_host_free_start_camera_result`.
typedef struct XHHostStartCameraResult {
  int64_t request_id;
  int32_t ok;
  char* error_code;
  char* error_message;
  char* error_details;
  int64_t texture_id;
  int32_t has_torch;
  int32_t torch_enabled;
  int32_t available_camera_count;
  char* active_camera_id;
  char* camera_facing;
  int32_t preview_width;
  int32_t preview_height;
  int32_t sensor_orientation;
  XHHostCameraInfo* cameras;
  int32_t camera_count;
} XHHostStartCameraResult;

/// Heap-allocated boolean/void result for `stopCamera`, `setTorch`, and
/// `openAppSettings`. Must be freed via `xh_host_free_bool_result`.
typedef struct XHHostBoolResult {
  int64_t request_id;
  int32_t ok;
  int32_t value;
  char* error_code;
  char* error_message;
} XHHostBoolResult;

/// Heap-allocated result for `pickImage`.
/// Must be freed via `xh_host_free_pick_image_result`.
typedef struct XHHostPickImageResult {
  int64_t request_id;
  int32_t ok;
  int32_t has_data;
  uint8_t* bytes;
  int32_t byte_length;
  char* file_path;
  char* error_code;
  char* error_message;
} XHHostPickImageResult;

/// Heap-allocated single-frame luminance packet emitted from native capture.
/// Must be freed via `xh_host_free_frame_packet`.
typedef struct XHHostFramePacket {
  uint64_t session_generation;
  uint8_t* bytes;
  int32_t byte_length;
  int32_t width;
  int32_t height;
  int32_t row_stride;
  int32_t format;
  int32_t sensor_orientation;
} XHHostFramePacket;

/// Platform driver function pointers registered by each OS `FlutterPlugin`.
typedef struct XHHostPlatformOps {
  void* user_data;
  void (*list_cameras)(void* user_data, int64_t request_id);
  void (*start_camera)(void* user_data,
                       int64_t request_id,
                       uint64_t session_generation,
                       const char* facing,
                       const char* camera_id);
  void (*stop_camera)(void* user_data, int64_t request_id);
  void (*set_torch)(void* user_data, int64_t request_id, int32_t enabled);
  void (*open_app_settings)(void* user_data, int64_t request_id);
  void (*pick_image)(void* user_data,
                     int64_t request_id,
                     int32_t prefer_file_path);
  void (*set_frame_stream_paused)(void* user_data, int32_t paused);
} XHHostPlatformOps;

typedef void (*XHHostCameraListCallback)(XHHostCameraListResult* result);
typedef void (*XHHostStartCameraCallback)(XHHostStartCameraResult* result);
typedef void (*XHHostBoolCallback)(XHHostBoolResult* result);
typedef void (*XHHostPickImageCallback)(XHHostPickImageResult* result);
typedef void (*XHHostFrameCallback)(XHHostFramePacket* packet);

// ---- Platform host registration (called by each platform's FlutterPlugin) ----

XH_HOST_EXPORT void xh_host_register_platform(const XHHostPlatformOps* ops);
XH_HOST_EXPORT void xh_host_unregister_platform(void* user_data);

// ---- Dart -> Native host commands (bound via ffigen) ----

/// Returns non-zero if a native FlutterPlugin host driver is currently bound.
XH_HOST_EXPORT int32_t xh_host_is_attached(void);

/// Registers Dart `NativeCallable.listener` callbacks and returns a non-zero
/// session token. Re-registering supersedes any earlier token and stops any
/// lingering camera session left behind by a Hot Restart.
XH_HOST_EXPORT uint64_t xh_host_register_callbacks(
    XHHostCameraListCallback on_camera_list,
    XHHostStartCameraCallback on_start_camera,
    XHHostBoolCallback on_bool_result,
    XHHostPickImageCallback on_pick_image,
    XHHostFrameCallback on_frame);

/// Unregisters Dart callbacks associated with `session_token`, guaranteeing no
/// callback trampoline fires after this call returns.
XH_HOST_EXPORT void xh_host_unregister_callbacks(uint64_t session_token);

XH_HOST_EXPORT void xh_host_list_cameras(int64_t request_id);

XH_HOST_EXPORT void xh_host_start_camera(int64_t request_id,
                                         uint64_t session_generation,
                                         const char* facing,
                                         const char* camera_id);

XH_HOST_EXPORT void xh_host_stop_camera(int64_t request_id);

XH_HOST_EXPORT void xh_host_set_torch(int64_t request_id, int32_t enabled);

XH_HOST_EXPORT void xh_host_open_app_settings(int64_t request_id);

XH_HOST_EXPORT void xh_host_pick_image(int64_t request_id,
                                       int32_t prefer_file_path);

XH_HOST_EXPORT void xh_host_set_frame_stream_paused(int32_t paused);

// ---- Native host -> Dart completion / frame emitters ----

XH_HOST_EXPORT void xh_host_complete_camera_list(
    int64_t request_id,
    int32_t ok,
    const char* error_code,
    const char* error_message,
    const XHHostCameraInfo* cameras,
    int32_t camera_count);

XH_HOST_EXPORT void xh_host_complete_start_camera(
    int64_t request_id,
    int32_t ok,
    const char* error_code,
    const char* error_message,
    const char* error_details,
    int64_t texture_id,
    int32_t has_torch,
    int32_t torch_enabled,
    int32_t available_camera_count,
    const char* active_camera_id,
    const char* camera_facing,
    int32_t preview_width,
    int32_t preview_height,
    int32_t sensor_orientation,
    const XHHostCameraInfo* cameras,
    int32_t camera_count);

XH_HOST_EXPORT void xh_host_complete_bool(int64_t request_id,
                                          int32_t ok,
                                          int32_t value,
                                          const char* error_code,
                                          const char* error_message);

XH_HOST_EXPORT void xh_host_complete_pick_image(int64_t request_id,
                                                int32_t ok,
                                                int32_t has_data,
                                                const uint8_t* bytes,
                                                int32_t byte_length,
                                                const char* file_path,
                                                const char* error_code,
                                                const char* error_message);

XH_HOST_EXPORT void xh_host_emit_camera_frame(uint64_t session_generation,
                                              const uint8_t* bytes,
                                              int32_t byte_length,
                                              int32_t width,
                                              int32_t height,
                                              int32_t row_stride,
                                              int32_t format,
                                              int32_t sensor_orientation);

// ---- Native heap cleanup (invoked by Dart after copying result data) ----

XH_HOST_EXPORT void xh_host_free_camera_list_result(
    XHHostCameraListResult* result);
XH_HOST_EXPORT void xh_host_free_start_camera_result(
    XHHostStartCameraResult* result);
XH_HOST_EXPORT void xh_host_free_bool_result(XHHostBoolResult* result);
XH_HOST_EXPORT void xh_host_free_pick_image_result(
    XHHostPickImageResult* result);
XH_HOST_EXPORT void xh_host_free_frame_packet(XHHostFramePacket* packet);

#ifdef __cplusplus
}
#endif

#endif  // XUE_HUA_BARCODE_SCANNER_SCANNER_HOST_FFI_H_
