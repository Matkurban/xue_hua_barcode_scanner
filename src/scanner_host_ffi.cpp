#include "scanner_host_ffi.h"

#include <atomic>
#include <condition_variable>
#include <cstdlib>
#include <cstring>
#include <mutex>

namespace {

std::mutex g_platform_mutex;
std::condition_variable g_platform_cv;
XHHostPlatformOps g_platform_ops{};
bool g_platform_attached = false;
int32_t g_platform_in_flight = 0;

std::mutex g_callback_mutex;
XHHostCameraListCallback g_cb_camera_list = nullptr;
XHHostStartCameraCallback g_cb_start_camera = nullptr;
XHHostBoolCallback g_cb_bool_result = nullptr;
XHHostPickImageCallback g_cb_pick_image = nullptr;
XHHostFrameCallback g_cb_frame = nullptr;
uint64_t g_callback_session_token = 0;
uint64_t g_next_session_token = 0;

std::atomic<bool> g_has_callbacks{false};
std::atomic<bool> g_camera_session_active{false};
std::atomic<int64_t> g_last_start_request_id{0};
std::atomic<uint64_t> g_active_generation{0};
std::atomic<bool> g_frame_stream_paused{false};

char* CopyCString(const char* src) {
  if (src == nullptr) {
    return nullptr;
  }
  const size_t len = std::strlen(src) + 1;
  char* dst = static_cast<char*>(std::malloc(len));
  if (dst != nullptr) {
    std::memcpy(dst, src, len);
  }
  return dst;
}

uint8_t* CopyBytes(const uint8_t* src, int32_t byte_length, int32_t* out_len) {
  if (src == nullptr || byte_length <= 0) {
    *out_len = 0;
    return nullptr;
  }
  const size_t alloc_size = static_cast<size_t>(byte_length);
  uint8_t* dst = static_cast<uint8_t*>(std::malloc(alloc_size));
  if (dst == nullptr) {
    *out_len = 0;
    return nullptr;
  }
  std::memcpy(dst, src, alloc_size);
  *out_len = byte_length;
  return dst;
}

XHHostCameraInfo* CopyCameraArray(const XHHostCameraInfo* src,
                                  int32_t count,
                                  int32_t* out_count) {
  if (src == nullptr || count <= 0) {
    *out_count = 0;
    return nullptr;
  }
  const size_t byte_size = static_cast<size_t>(count) * sizeof(XHHostCameraInfo);
  XHHostCameraInfo* dst = static_cast<XHHostCameraInfo*>(std::malloc(byte_size));
  if (dst == nullptr) {
    *out_count = 0;
    return nullptr;
  }
  std::memset(dst, 0, byte_size);
  for (int32_t i = 0; i < count; ++i) {
    dst[i].id = CopyCString(src[i].id);
    dst[i].label = CopyCString(src[i].label);
    dst[i].facing = CopyCString(src[i].facing);
  }
  *out_count = count;
  return dst;
}

void FreeCameraArray(XHHostCameraInfo* cameras, int32_t count) {
  if (cameras == nullptr) {
    return;
  }
  for (int32_t i = 0; i < count; ++i) {
    std::free(cameras[i].id);
    std::free(cameras[i].label);
    std::free(cameras[i].facing);
  }
  std::free(cameras);
}

bool AcquirePlatformOps(XHHostPlatformOps* out_ops) {
  std::lock_guard<std::mutex> lock(g_platform_mutex);
  if (!g_platform_attached) {
    return false;
  }
  *out_ops = g_platform_ops;
  ++g_platform_in_flight;
  return true;
}

void ReleasePlatformOps() {
  std::lock_guard<std::mutex> lock(g_platform_mutex);
  if (g_platform_in_flight > 0) {
    --g_platform_in_flight;
  }
  if (g_platform_in_flight == 0) {
    g_platform_cv.notify_all();
  }
}

}  // namespace

extern "C" {

void xh_host_register_platform(const XHHostPlatformOps* ops) {
  if (ops == nullptr) {
    return;
  }
  std::lock_guard<std::mutex> lock(g_platform_mutex);
  g_platform_ops = *ops;
  g_platform_attached = true;
}

void xh_host_unregister_platform(void* user_data) {
  std::unique_lock<std::mutex> lock(g_platform_mutex);
  if (!g_platform_attached) {
    return;
  }
  if (user_data != nullptr && g_platform_ops.user_data != nullptr &&
      g_platform_ops.user_data != user_data) {
    return;
  }
  g_platform_ops = XHHostPlatformOps{};
  g_platform_attached = false;
  g_camera_session_active.store(false, std::memory_order_release);
  g_active_generation.store(0, std::memory_order_release);
  g_platform_cv.wait(lock, []() { return g_platform_in_flight == 0; });
}

int32_t xh_host_is_attached(void) {
  std::lock_guard<std::mutex> lock(g_platform_mutex);
  return g_platform_attached ? 1 : 0;
}

uint64_t xh_host_register_callbacks(
    XHHostCameraListCallback on_camera_list,
    XHHostStartCameraCallback on_start_camera,
    XHHostBoolCallback on_bool_result,
    XHHostPickImageCallback on_pick_image,
    XHHostFrameCallback on_frame) {
  bool should_stop_previous = false;
  uint64_t new_token = 0;

  {
    std::lock_guard<std::mutex> lock(g_callback_mutex);
    if (g_callback_session_token != 0 &&
        g_camera_session_active.exchange(false, std::memory_order_acq_rel)) {
      should_stop_previous = true;
    }
    g_active_generation.store(0, std::memory_order_release);
    g_frame_stream_paused.store(false, std::memory_order_release);

    g_cb_camera_list = on_camera_list;
    g_cb_start_camera = on_start_camera;
    g_cb_bool_result = on_bool_result;
    g_cb_pick_image = on_pick_image;
    g_cb_frame = on_frame;

    new_token = ++g_next_session_token;
    if (new_token == 0) {
      new_token = ++g_next_session_token;
    }
    g_callback_session_token = new_token;
    const bool any_cb = on_camera_list != nullptr ||
                        on_start_camera != nullptr ||
                        on_bool_result != nullptr ||
                        on_pick_image != nullptr ||
                        on_frame != nullptr;
    g_has_callbacks.store(any_cb, std::memory_order_release);
  }

  if (should_stop_previous) {
    XHHostPlatformOps ops{};
    if (AcquirePlatformOps(&ops)) {
      if (ops.stop_camera != nullptr) {
        ops.stop_camera(ops.user_data, 0);
      }
      ReleasePlatformOps();
    }
  }

  return new_token;
}

void xh_host_unregister_callbacks(uint64_t session_token) {
  std::lock_guard<std::mutex> lock(g_callback_mutex);
  if (session_token != 0 && g_callback_session_token != session_token) {
    return;
  }
  g_cb_camera_list = nullptr;
  g_cb_start_camera = nullptr;
  g_cb_bool_result = nullptr;
  g_cb_pick_image = nullptr;
  g_cb_frame = nullptr;
  g_callback_session_token = 0;
  g_has_callbacks.store(false, std::memory_order_release);
  g_active_generation.store(0, std::memory_order_release);
}

void xh_host_list_cameras(int64_t request_id) {
  XHHostPlatformOps ops{};
  if (!AcquirePlatformOps(&ops)) {
    xh_host_complete_camera_list(
        request_id, 0, "NO_HOST", "Native scanner host is not attached.", nullptr, 0);
    return;
  }
  if (ops.list_cameras == nullptr) {
    ReleasePlatformOps();
    xh_host_complete_camera_list(
        request_id,
        0,
        "UNIMPLEMENTED",
        "Native host list_cameras is not implemented.",
        nullptr,
        0);
    return;
  }
  ops.list_cameras(ops.user_data, request_id);
  ReleasePlatformOps();
}

void xh_host_start_camera(int64_t request_id,
                          uint64_t session_generation,
                          const char* facing,
                          const char* camera_id) {
  g_last_start_request_id.store(request_id, std::memory_order_release);
  g_active_generation.store(session_generation, std::memory_order_release);
  g_camera_session_active.store(true, std::memory_order_release);
  g_frame_stream_paused.store(false, std::memory_order_release);

  XHHostPlatformOps ops{};
  if (!AcquirePlatformOps(&ops)) {
    g_camera_session_active.store(false, std::memory_order_release);
    g_active_generation.store(0, std::memory_order_release);
    xh_host_complete_start_camera(
        request_id,
        0,
        "NO_HOST",
        "Native scanner host is not attached.",
        nullptr,
        -1,
        0,
        0,
        0,
        nullptr,
        facing,
        0,
        0,
        0,
        nullptr,
        0);
    return;
  }
  if (ops.start_camera == nullptr) {
    ReleasePlatformOps();
    g_camera_session_active.store(false, std::memory_order_release);
    g_active_generation.store(0, std::memory_order_release);
    xh_host_complete_start_camera(
        request_id,
        0,
        "UNIMPLEMENTED",
        "Native host start_camera is not implemented.",
        nullptr,
        -1,
        0,
        0,
        0,
        nullptr,
        facing,
        0,
        0,
        0,
        nullptr,
        0);
    return;
  }
  ops.start_camera(ops.user_data, request_id, session_generation, facing, camera_id);
  ReleasePlatformOps();
}

void xh_host_stop_camera(int64_t request_id) {
  g_camera_session_active.store(false, std::memory_order_release);
  g_active_generation.store(0, std::memory_order_release);

  XHHostPlatformOps ops{};
  if (!AcquirePlatformOps(&ops)) {
    xh_host_complete_bool(request_id, 1, 1, nullptr, nullptr);
    return;
  }
  if (ops.stop_camera == nullptr) {
    ReleasePlatformOps();
    xh_host_complete_bool(request_id, 1, 1, nullptr, nullptr);
    return;
  }
  ops.stop_camera(ops.user_data, request_id);
  ReleasePlatformOps();
}

void xh_host_set_torch(int64_t request_id, int32_t enabled) {
  XHHostPlatformOps ops{};
  if (!AcquirePlatformOps(&ops)) {
    xh_host_complete_bool(request_id, 1, 0, nullptr, nullptr);
    return;
  }
  if (ops.set_torch == nullptr) {
    ReleasePlatformOps();
    xh_host_complete_bool(request_id, 1, 0, nullptr, nullptr);
    return;
  }
  ops.set_torch(ops.user_data, request_id, enabled);
  ReleasePlatformOps();
}

void xh_host_open_app_settings(int64_t request_id) {
  XHHostPlatformOps ops{};
  if (!AcquirePlatformOps(&ops)) {
    xh_host_complete_bool(request_id, 1, 0, nullptr, nullptr);
    return;
  }
  if (ops.open_app_settings == nullptr) {
    ReleasePlatformOps();
    xh_host_complete_bool(request_id, 1, 0, nullptr, nullptr);
    return;
  }
  ops.open_app_settings(ops.user_data, request_id);
  ReleasePlatformOps();
}

void xh_host_pick_image(int64_t request_id, int32_t prefer_file_path) {
  XHHostPlatformOps ops{};
  if (!AcquirePlatformOps(&ops)) {
    xh_host_complete_pick_image(
        request_id, 1, 0, nullptr, 0, nullptr, nullptr, nullptr);
    return;
  }
  if (ops.pick_image == nullptr) {
    ReleasePlatformOps();
    xh_host_complete_pick_image(
        request_id, 1, 0, nullptr, 0, nullptr, nullptr, nullptr);
    return;
  }
  ops.pick_image(ops.user_data, request_id, prefer_file_path);
  ReleasePlatformOps();
}

void xh_host_set_frame_stream_paused(int32_t paused) {
  g_frame_stream_paused.store(paused != 0, std::memory_order_release);
  XHHostPlatformOps ops{};
  if (!AcquirePlatformOps(&ops)) {
    return;
  }
  if (ops.set_frame_stream_paused != nullptr) {
    ops.set_frame_stream_paused(ops.user_data, paused);
  }
  ReleasePlatformOps();
}

void xh_host_complete_camera_list(
    int64_t request_id,
    int32_t ok,
    const char* error_code,
    const char* error_message,
    const XHHostCameraInfo* cameras,
    int32_t camera_count) {
  if (request_id == 0 || !g_has_callbacks.load(std::memory_order_acquire)) {
    return;
  }
  auto* result = static_cast<XHHostCameraListResult*>(
      std::calloc(1, sizeof(XHHostCameraListResult)));
  if (result == nullptr) {
    return;
  }
  result->request_id = request_id;
  result->ok = ok;
  result->error_code = CopyCString(error_code);
  result->error_message = CopyCString(error_message);
  result->cameras = CopyCameraArray(cameras, camera_count, &result->camera_count);

  std::lock_guard<std::mutex> lock(g_callback_mutex);
  if (g_cb_camera_list != nullptr) {
    g_cb_camera_list(result);
  } else {
    xh_host_free_camera_list_result(result);
  }
}

void xh_host_complete_start_camera(
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
    int32_t camera_count) {
  if (ok == 0 && request_id == g_last_start_request_id.load(std::memory_order_acquire)) {
    g_camera_session_active.store(false, std::memory_order_release);
    g_active_generation.store(0, std::memory_order_release);
  }
  if (request_id == 0 || !g_has_callbacks.load(std::memory_order_acquire)) {
    return;
  }
  auto* result = static_cast<XHHostStartCameraResult*>(
      std::calloc(1, sizeof(XHHostStartCameraResult)));
  if (result == nullptr) {
    return;
  }
  result->request_id = request_id;
  result->ok = ok;
  result->error_code = CopyCString(error_code);
  result->error_message = CopyCString(error_message);
  result->error_details = CopyCString(error_details);
  result->texture_id = texture_id;
  result->has_torch = has_torch;
  result->torch_enabled = torch_enabled;
  result->available_camera_count = available_camera_count;
  result->active_camera_id = CopyCString(active_camera_id);
  result->camera_facing = CopyCString(camera_facing);
  result->preview_width = preview_width;
  result->preview_height = preview_height;
  result->sensor_orientation = sensor_orientation;
  result->cameras = CopyCameraArray(cameras, camera_count, &result->camera_count);

  std::lock_guard<std::mutex> lock(g_callback_mutex);
  if (g_cb_start_camera != nullptr) {
    g_cb_start_camera(result);
  } else {
    xh_host_free_start_camera_result(result);
  }
}

void xh_host_complete_bool(int64_t request_id,
                           int32_t ok,
                           int32_t value,
                           const char* error_code,
                           const char* error_message) {
  if (request_id == 0 || !g_has_callbacks.load(std::memory_order_acquire)) {
    return;
  }
  auto* result = static_cast<XHHostBoolResult*>(
      std::calloc(1, sizeof(XHHostBoolResult)));
  if (result == nullptr) {
    return;
  }
  result->request_id = request_id;
  result->ok = ok;
  result->value = value;
  result->error_code = CopyCString(error_code);
  result->error_message = CopyCString(error_message);

  std::lock_guard<std::mutex> lock(g_callback_mutex);
  if (g_cb_bool_result != nullptr) {
    g_cb_bool_result(result);
  } else {
    xh_host_free_bool_result(result);
  }
}

void xh_host_complete_pick_image(int64_t request_id,
                                 int32_t ok,
                                 int32_t has_data,
                                 const uint8_t* bytes,
                                 int32_t byte_length,
                                 const char* file_path,
                                 const char* error_code,
                                 const char* error_message) {
  if (request_id == 0 || !g_has_callbacks.load(std::memory_order_acquire)) {
    return;
  }
  auto* result = static_cast<XHHostPickImageResult*>(
      std::calloc(1, sizeof(XHHostPickImageResult)));
  if (result == nullptr) {
    return;
  }
  result->request_id = request_id;
  result->ok = ok;
  result->has_data = has_data;
  if (has_data != 0 && bytes != nullptr && byte_length > 0) {
    result->bytes = CopyBytes(bytes, byte_length, &result->byte_length);
  }
  result->file_path = CopyCString(file_path);
  result->error_code = CopyCString(error_code);
  result->error_message = CopyCString(error_message);

  std::lock_guard<std::mutex> lock(g_callback_mutex);
  if (g_cb_pick_image != nullptr) {
    g_cb_pick_image(result);
  } else {
    xh_host_free_pick_image_result(result);
  }
}

void xh_host_emit_camera_frame(uint64_t session_generation,
                               const uint8_t* bytes,
                               int32_t byte_length,
                               int32_t width,
                               int32_t height,
                               int32_t row_stride,
                               int32_t format,
                               int32_t sensor_orientation) {
  if (bytes == nullptr || byte_length <= 0 || width <= 0 || height <= 0) {
    return;
  }
  if (!g_has_callbacks.load(std::memory_order_acquire) ||
      g_frame_stream_paused.load(std::memory_order_acquire)) {
    return;
  }
  const uint64_t active_gen = g_active_generation.load(std::memory_order_acquire);
  if (active_gen == 0 ||
      (session_generation != 0 && session_generation != active_gen)) {
    return;
  }

  auto* packet = static_cast<XHHostFramePacket*>(
      std::calloc(1, sizeof(XHHostFramePacket)));
  if (packet == nullptr) {
    return;
  }
  packet->session_generation =
      session_generation != 0 ? session_generation : active_gen;
  packet->bytes = CopyBytes(bytes, byte_length, &packet->byte_length);
  if (packet->bytes == nullptr) {
    std::free(packet);
    return;
  }
  packet->width = width;
  packet->height = height;
  packet->row_stride = row_stride;
  packet->format = format;
  packet->sensor_orientation = sensor_orientation;

  std::lock_guard<std::mutex> lock(g_callback_mutex);
  if (g_cb_frame != nullptr &&
      g_active_generation.load(std::memory_order_acquire) == packet->session_generation) {
    g_cb_frame(packet);
  } else {
    xh_host_free_frame_packet(packet);
  }
}

void xh_host_free_camera_list_result(XHHostCameraListResult* result) {
  if (result == nullptr) {
    return;
  }
  std::free(result->error_code);
  std::free(result->error_message);
  FreeCameraArray(result->cameras, result->camera_count);
  std::free(result);
}

void xh_host_free_start_camera_result(XHHostStartCameraResult* result) {
  if (result == nullptr) {
    return;
  }
  std::free(result->error_code);
  std::free(result->error_message);
  std::free(result->error_details);
  std::free(result->active_camera_id);
  std::free(result->camera_facing);
  FreeCameraArray(result->cameras, result->camera_count);
  std::free(result);
}

void xh_host_free_bool_result(XHHostBoolResult* result) {
  if (result == nullptr) {
    return;
  }
  std::free(result->error_code);
  std::free(result->error_message);
  std::free(result);
}

void xh_host_free_pick_image_result(XHHostPickImageResult* result) {
  if (result == nullptr) {
    return;
  }
  std::free(result->bytes);
  std::free(result->file_path);
  std::free(result->error_code);
  std::free(result->error_message);
  std::free(result);
}

void xh_host_free_frame_packet(XHHostFramePacket* packet) {
  if (packet == nullptr) {
    return;
  }
  std::free(packet->bytes);
  std::free(packet);
}

}  // extern "C"
