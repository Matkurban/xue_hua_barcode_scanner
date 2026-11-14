#include "include/xue_hua_barcode_scanner/xue_hua_barcode_scanner_plugin.h"

#include "linux_file_chooser.h"
#include "linux_v4l2_enumerator.h"
#include "scanner_host_ffi.h"

#include <flutter_linux/flutter_linux.h>

#include <vector>

#define XUE_HUA_BARCODE_SCANNER_PLUGIN(obj) \
  (G_TYPE_CHECK_INSTANCE_CAST((obj), xue_hua_barcode_scanner_plugin_get_type(), \
                              XueHuaBarcodeScannerPlugin))

struct _XueHuaBarcodeScannerPlugin {
  GObject parent_instance;
  FlPluginRegistrar* registrar;
  volatile gint disposed;
};

G_DEFINE_TYPE(XueHuaBarcodeScannerPlugin,
              xue_hua_barcode_scanner_plugin,
              g_object_get_type())

namespace {

void OnFfiListCameras(void* /*user_data*/, int64_t request_id) {
  std::vector<xue_hua_barcode_scanner::V4l2VideoDevice> devices =
      xue_hua_barcode_scanner::ListV4l2VideoDevices();
  std::vector<XHHostCameraInfo> infos;
  infos.reserve(devices.size());
  for (auto& device : devices) {
    XHHostCameraInfo info{};
    info.id = const_cast<char*>(device.id.c_str());
    info.label = const_cast<char*>(device.label.c_str());
    info.facing = const_cast<char*>(device.facing.c_str());
    infos.push_back(info);
  }
  xh_host_complete_camera_list(
      request_id,
      1,
      nullptr,
      nullptr,
      infos.empty() ? nullptr : infos.data(),
      static_cast<int32_t>(infos.size()));
}

void OnFfiStartCamera(void* /*user_data*/,
                      int64_t request_id,
                      uint64_t /*session_generation*/,
                      const char* /*facing*/,
                      const char* /*camera_id*/) {
  xh_host_complete_start_camera(
      request_id,
      0,
      "NO_CAMERA",
      "No V4L2 camera stream active.",
      nullptr,
      -1,
      0,
      0,
      0,
      nullptr,
      "external",
      0,
      0,
      0,
      nullptr,
      0);
}

void OnFfiStopCamera(void* /*user_data*/, int64_t request_id) {
  if (request_id != 0) {
    xh_host_complete_bool(request_id, 1, 1, nullptr, nullptr);
  }
}

void OnFfiSetTorch(void* /*user_data*/,
                   int64_t request_id,
                   int32_t /*enabled*/) {
  xh_host_complete_bool(request_id, 1, 0, nullptr, nullptr);
}

void OnFfiOpenAppSettings(void* /*user_data*/, int64_t request_id) {
  xh_host_complete_bool(request_id, 1, 0, nullptr, nullptr);
}

void OnFfiPickImage(void* user_data,
                    int64_t request_id,
                    int32_t /*prefer_file_path*/) {
  if (user_data == nullptr) {
    xh_host_complete_pick_image(
        request_id, 1, 0, nullptr, 0, nullptr, nullptr, nullptr);
    return;
  }
  XueHuaBarcodeScannerPlugin* self = XUE_HUA_BARCODE_SCANNER_PLUGIN(user_data);
  if (g_atomic_int_get(&self->disposed) != 0 || self->registrar == nullptr) {
    xh_host_complete_pick_image(
        request_id, 1, 0, nullptr, 0, nullptr, nullptr, nullptr);
    return;
  }
  xue_hua_barcode_scanner::PickImageFileWithGtkDialogAsync(
      self->registrar, request_id);
}

void OnFfiSetFrameStreamPaused(void* /*user_data*/, int32_t /*paused*/) {}

}  // namespace

static void xue_hua_barcode_scanner_plugin_dispose(GObject* object) {
  XueHuaBarcodeScannerPlugin* self = XUE_HUA_BARCODE_SCANNER_PLUGIN(object);
  g_atomic_int_set(&self->disposed, 1);
  xh_host_unregister_platform(self);
  g_clear_object(&self->registrar);
  G_OBJECT_CLASS(xue_hua_barcode_scanner_plugin_parent_class)->dispose(object);
}

static void xue_hua_barcode_scanner_plugin_class_init(
    XueHuaBarcodeScannerPluginClass* klass) {
  G_OBJECT_CLASS(klass)->dispose = xue_hua_barcode_scanner_plugin_dispose;
}

static void xue_hua_barcode_scanner_plugin_init(
    XueHuaBarcodeScannerPlugin* self) {
  self->registrar = nullptr;
  g_atomic_int_set(&self->disposed, 0);
}

void xue_hua_barcode_scanner_plugin_register_with_registrar(
    FlPluginRegistrar* registrar) {
  XueHuaBarcodeScannerPlugin* plugin = XUE_HUA_BARCODE_SCANNER_PLUGIN(
      g_object_new(xue_hua_barcode_scanner_plugin_get_type(), nullptr));
  plugin->registrar = FL_PLUGIN_REGISTRAR(g_object_ref(registrar));

  XHHostPlatformOps ops{};
  ops.user_data = plugin;
  ops.list_cameras = &OnFfiListCameras;
  ops.start_camera = &OnFfiStartCamera;
  ops.stop_camera = &OnFfiStopCamera;
  ops.set_torch = &OnFfiSetTorch;
  ops.open_app_settings = &OnFfiOpenAppSettings;
  ops.pick_image = &OnFfiPickImage;
  ops.set_frame_stream_paused = &OnFfiSetFrameStreamPaused;
  xh_host_register_platform(&ops);

  g_object_set_data_full(
      G_OBJECT(registrar),
      "xue_hua_barcode_scanner_plugin",
      g_object_ref(plugin),
      g_object_unref);

  g_object_unref(plugin);
}
