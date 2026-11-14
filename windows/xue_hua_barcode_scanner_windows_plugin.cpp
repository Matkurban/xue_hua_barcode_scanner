#include "xue_hua_barcode_scanner_windows_plugin.h"

#include "scanner_host_ffi.h"
#include "windows_system_dialogs.h"

#include <mfapi.h>
#include <objbase.h>

#include <utility>

#ifdef _MSC_VER
#pragma comment(lib, "Ole32.lib")
#endif

namespace xue_hua_barcode_scanner {

namespace {

constexpr UINT kRunUiTaskMessage = WM_APP + 0x486;

void OnFfiListCameras(void* user_data, int64_t request_id) {
  if (user_data == nullptr) {
    xh_host_complete_camera_list(request_id, 1, nullptr, nullptr, nullptr, 0);
    return;
  }
  auto* plugin = static_cast<XueHuaBarcodeScannerWindowsPlugin*>(user_data);
  plugin->PostMfTask([plugin, request_id]() {
    plugin->HandleListCameras(request_id);
  });
}

void OnFfiStartCamera(
    void* user_data,
    int64_t request_id,
    uint64_t session_generation,
    const char* facing,
    const char* camera_id) {
  (void)facing;
  std::string camera_id_copy = camera_id != nullptr ? camera_id : "";
  if (user_data == nullptr) {
    xh_host_complete_start_camera(
        request_id,
        0,
        "NO_HOST",
        "Native Windows host is not attached.",
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
    return;
  }
  auto* plugin = static_cast<XueHuaBarcodeScannerWindowsPlugin*>(user_data);
  plugin->PostMfTask([plugin,
                      request_id,
                      session_generation,
                      id = std::move(camera_id_copy)]() {
    plugin->HandleStartCamera(request_id, session_generation, id);
  });
}

void OnFfiStopCamera(void* user_data, int64_t request_id) {
  if (user_data == nullptr) {
    if (request_id != 0) {
      xh_host_complete_bool(request_id, 1, 1, nullptr, nullptr);
    }
    return;
  }
  auto* plugin = static_cast<XueHuaBarcodeScannerWindowsPlugin*>(user_data);
  plugin->PostMfTask([plugin, request_id]() {
    plugin->HandleStopCamera(request_id);
  });
}

void OnFfiSetTorch(void* user_data, int64_t request_id, int32_t enabled) {
  (void)user_data;
  (void)enabled;
  xh_host_complete_bool(request_id, 1, 0, nullptr, nullptr);
}

void OnFfiOpenAppSettings(void* user_data, int64_t request_id) {
  if (user_data == nullptr) {
    xh_host_complete_bool(request_id, 1, 0, nullptr, nullptr);
    return;
  }
  auto* plugin = static_cast<XueHuaBarcodeScannerWindowsPlugin*>(user_data);
  plugin->PostUiTask([plugin, request_id]() {
    plugin->HandleOpenAppSettings(request_id);
  });
}

void OnFfiPickImage(
    void* user_data,
    int64_t request_id,
    int32_t prefer_file_path) {
  (void)prefer_file_path;
  if (user_data == nullptr) {
    xh_host_complete_pick_image(
        request_id, 1, 0, nullptr, 0, nullptr, nullptr, nullptr);
    return;
  }
  auto* plugin = static_cast<XueHuaBarcodeScannerWindowsPlugin*>(user_data);
  plugin->PostUiTask([plugin, request_id]() {
    plugin->HandlePickImage(request_id);
  });
}

void OnFfiSetFrameStreamPaused(void* user_data, int32_t paused) {
  if (user_data == nullptr) {
    return;
  }
  auto* plugin = static_cast<XueHuaBarcodeScannerWindowsPlugin*>(user_data);
  plugin->HandleSetFrameStreamPaused(paused != 0);
}

}  // namespace

void XueHuaBarcodeScannerWindowsPlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows* registrar) {
  auto plugin = std::make_unique<XueHuaBarcodeScannerWindowsPlugin>(registrar);
  registrar->AddPlugin(std::move(plugin));
}

XueHuaBarcodeScannerWindowsPlugin::XueHuaBarcodeScannerWindowsPlugin(
    flutter::PluginRegistrarWindows* registrar)
    : texture_registrar_(registrar->texture_registrar()) {
  if (flutter::FlutterView* view = registrar->GetView()) {
    view_hwnd_ = view->GetNativeWindow();
  }

  msg_hwnd_ = CreateWindowExW(
      0,
      L"STATIC",
      L"",
      0,
      0,
      0,
      0,
      0,
      HWND_MESSAGE,
      nullptr,
      nullptr,
      nullptr);
  if (msg_hwnd_ != nullptr) {
    SetWindowLongPtrW(
        msg_hwnd_, GWLP_USERDATA, reinterpret_cast<LONG_PTR>(this));
    original_wnd_proc_ = reinterpret_cast<WNDPROC>(SetWindowLongPtrW(
        msg_hwnd_,
        GWLP_WNDPROC,
        reinterpret_cast<LONG_PTR>(&MessageWndProc)));
  }

  texture_variant_ = std::make_unique<flutter::TextureVariant>(
      flutter::PixelBufferTexture(
          [this](size_t, size_t) -> const FlutterDesktopPixelBuffer* {
            return camera_capture_ != nullptr
                       ? camera_capture_->CopyPixelBuffer()
                       : nullptr;
          }));
  texture_id_ = texture_registrar_->RegisterTexture(texture_variant_.get());

  camera_capture_ = std::make_unique<WindowsCameraCapture>(
      texture_registrar_, texture_id_);

  mf_thread_ = std::thread([this]() { MfWorkerLoop(); });

  XHHostPlatformOps ops{};
  ops.user_data = this;
  ops.list_cameras = &OnFfiListCameras;
  ops.start_camera = &OnFfiStartCamera;
  ops.stop_camera = &OnFfiStopCamera;
  ops.set_torch = &OnFfiSetTorch;
  ops.open_app_settings = &OnFfiOpenAppSettings;
  ops.pick_image = &OnFfiPickImage;
  ops.set_frame_stream_paused = &OnFfiSetFrameStreamPaused;
  xh_host_register_platform(&ops);
}

XueHuaBarcodeScannerWindowsPlugin::~XueHuaBarcodeScannerWindowsPlugin() {
  xh_host_unregister_platform(this);

  {
    std::lock_guard<std::mutex> lock(mf_mutex_);
    mf_shutting_down_ = true;
  }
  mf_cv_.notify_all();
  if (mf_thread_.joinable()) {
    mf_thread_.join();
  }

  if (msg_hwnd_ != nullptr) {
    if (original_wnd_proc_ != nullptr) {
      SetWindowLongPtrW(
          msg_hwnd_,
          GWLP_WNDPROC,
          reinterpret_cast<LONG_PTR>(original_wnd_proc_));
      original_wnd_proc_ = nullptr;
    }
    SetWindowLongPtrW(msg_hwnd_, GWLP_USERDATA, 0);
    DestroyWindow(msg_hwnd_);
    msg_hwnd_ = nullptr;
  }
  {
    std::lock_guard<std::mutex> lock(ui_mutex_);
    ui_tasks_.clear();
  }

  if (camera_capture_ != nullptr) {
    camera_capture_->StopCapture();
    camera_capture_.reset();
  }
  if (texture_id_ >= 0 && texture_registrar_ != nullptr) {
    texture_registrar_->UnregisterTexture(texture_id_);
    texture_id_ = -1;
  }
}

void XueHuaBarcodeScannerWindowsPlugin::PostMfTask(std::function<void()> task) {
  {
    std::lock_guard<std::mutex> lock(mf_mutex_);
    if (mf_shutting_down_) {
      return;
    }
    mf_tasks_.push_back(std::move(task));
  }
  mf_cv_.notify_one();
}

void XueHuaBarcodeScannerWindowsPlugin::PostUiTask(std::function<void()> task) {
  HWND target = nullptr;
  {
    std::lock_guard<std::mutex> lock(ui_mutex_);
    target = msg_hwnd_;
    if (target == nullptr) {
      return;
    }
    ui_tasks_.push_back(std::move(task));
  }
  if (PostMessageW(target, kRunUiTaskMessage, 0, 0) == FALSE) {
    std::lock_guard<std::mutex> lock(ui_mutex_);
    ui_tasks_.clear();
  }
}

void XueHuaBarcodeScannerWindowsPlugin::MfWorkerLoop() {
  const HRESULT com_hr = CoInitializeEx(nullptr, COINIT_MULTITHREADED);
  const HRESULT mf_hr = MFStartup(MF_VERSION);

  for (;;) {
    std::function<void()> task;
    {
      std::unique_lock<std::mutex> lock(mf_mutex_);
      mf_cv_.wait(lock, [this]() {
        return mf_shutting_down_ || !mf_tasks_.empty();
      });
      if (mf_shutting_down_ && mf_tasks_.empty()) {
        break;
      }
      task = std::move(mf_tasks_.front());
      mf_tasks_.pop_front();
    }
    if (task) {
      task();
    }
  }

  if (SUCCEEDED(mf_hr)) {
    MFShutdown();
  }
  if (com_hr == S_OK || com_hr == S_FALSE) {
    CoUninitialize();
  }
}

void XueHuaBarcodeScannerWindowsPlugin::DrainUiTasks() {
  std::deque<std::function<void()>> tasks;
  {
    std::lock_guard<std::mutex> lock(ui_mutex_);
    tasks.swap(ui_tasks_);
  }
  for (std::function<void()>& task : tasks) {
    if (task) {
      task();
    }
  }
}

HWND XueHuaBarcodeScannerWindowsPlugin::OwnerWindow() const {
  if (view_hwnd_ == nullptr) {
    return nullptr;
  }
  HWND top = GetAncestor(view_hwnd_, GA_ROOT);
  return top != nullptr ? top : view_hwnd_;
}

LRESULT CALLBACK XueHuaBarcodeScannerWindowsPlugin::MessageWndProc(
    HWND hwnd,
    UINT message,
    WPARAM wparam,
    LPARAM lparam) {
  auto* plugin = reinterpret_cast<XueHuaBarcodeScannerWindowsPlugin*>(
      GetWindowLongPtrW(hwnd, GWLP_USERDATA));
  if (message == kRunUiTaskMessage && plugin != nullptr) {
    plugin->DrainUiTasks();
    return 0;
  }
  if (plugin != nullptr && plugin->original_wnd_proc_ != nullptr) {
    return CallWindowProcW(
        plugin->original_wnd_proc_, hwnd, message, wparam, lparam);
  }
  return DefWindowProcW(hwnd, message, wparam, lparam);
}

void XueHuaBarcodeScannerWindowsPlugin::HandleListCameras(int64_t request_id) {
  if (camera_capture_ == nullptr) {
    xh_host_complete_camera_list(request_id, 1, nullptr, nullptr, nullptr, 0);
    return;
  }
  camera_capture_->ListCamerasFfi(request_id);
}

void XueHuaBarcodeScannerWindowsPlugin::HandleStartCamera(
    int64_t request_id,
    uint64_t session_generation,
    std::string camera_id) {
  if (camera_capture_ == nullptr) {
    xh_host_complete_start_camera(
        request_id,
        0,
        "NO_HOST",
        "Windows camera controller is unavailable.",
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
    return;
  }
  camera_capture_->StartCapture(request_id, session_generation, camera_id);
}

void XueHuaBarcodeScannerWindowsPlugin::HandleStopCamera(int64_t request_id) {
  if (camera_capture_ != nullptr) {
    camera_capture_->StopCapture();
  }
  if (request_id != 0) {
    xh_host_complete_bool(request_id, 1, 1, nullptr, nullptr);
  }
}

void XueHuaBarcodeScannerWindowsPlugin::HandleOpenAppSettings(
    int64_t request_id) {
  const bool opened = OpenPrivacyWebcamSettings();
  xh_host_complete_bool(request_id, 1, opened ? 1 : 0, nullptr, nullptr);
}

void XueHuaBarcodeScannerWindowsPlugin::HandlePickImage(int64_t request_id) {
  const std::string path = OpenImageFileDialog(OwnerWindow());
  xh_host_complete_pick_image(
      request_id,
      1,
      path.empty() ? 0 : 1,
      nullptr,
      0,
      path.empty() ? nullptr : path.c_str(),
      nullptr,
      nullptr);
}

void XueHuaBarcodeScannerWindowsPlugin::HandleSetFrameStreamPaused(
    bool paused) {
  if (camera_capture_ != nullptr) {
    camera_capture_->SetFrameStreamPaused(paused);
  }
}

}  // namespace xue_hua_barcode_scanner
