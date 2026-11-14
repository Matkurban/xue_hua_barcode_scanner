#ifndef XUE_HUA_BARCODE_SCANNER_WINDOWS_PLUGIN_H_
#define XUE_HUA_BARCODE_SCANNER_WINDOWS_PLUGIN_H_

#include "windows_camera_capture.h"

#include <flutter/plugin_registrar_windows.h>
#include <flutter/texture_registrar.h>

#include <condition_variable>
#include <cstdint>
#include <deque>
#include <functional>
#include <memory>
#include <mutex>
#include <string>
#include <thread>

namespace xue_hua_barcode_scanner {

/// Pure FFI Windows host for the barcode scanner plugin.
/// Owns Flutter pixel-buffer texture registration, routes MediaFoundation
/// operations through a dedicated COM MTA serial worker, and dispatches Win32
/// file-picker/settings UI onto the STA platform thread via a message-only HWND.
class XueHuaBarcodeScannerWindowsPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows* registrar);

  explicit XueHuaBarcodeScannerWindowsPlugin(
      flutter::PluginRegistrarWindows* registrar);
  ~XueHuaBarcodeScannerWindowsPlugin() override;

  void PostMfTask(std::function<void()> task);
  void PostUiTask(std::function<void()> task);

  void HandleListCameras(int64_t request_id);
  void HandleStartCamera(
      int64_t request_id,
      uint64_t session_generation,
      std::string camera_id);
  void HandleStopCamera(int64_t request_id);
  void HandleOpenAppSettings(int64_t request_id);
  void HandlePickImage(int64_t request_id);
  void HandleSetFrameStreamPaused(bool paused);

 private:
  void MfWorkerLoop();
  void DrainUiTasks();
  HWND OwnerWindow() const;

  static LRESULT CALLBACK MessageWndProc(
      HWND hwnd,
      UINT message,
      WPARAM wparam,
      LPARAM lparam);

  flutter::TextureRegistrar* texture_registrar_ = nullptr;
  HWND view_hwnd_ = nullptr;

  HWND msg_hwnd_ = nullptr;
  WNDPROC original_wnd_proc_ = nullptr;
  std::mutex ui_mutex_;
  std::deque<std::function<void()>> ui_tasks_;

  std::mutex mf_mutex_;
  std::condition_variable mf_cv_;
  std::deque<std::function<void()>> mf_tasks_;
  bool mf_shutting_down_ = false;
  std::thread mf_thread_;

  std::unique_ptr<flutter::TextureVariant> texture_variant_;
  int64_t texture_id_ = -1;
  std::unique_ptr<WindowsCameraCapture> camera_capture_;
};

}  // namespace xue_hua_barcode_scanner

#endif  // XUE_HUA_BARCODE_SCANNER_WINDOWS_PLUGIN_H_
