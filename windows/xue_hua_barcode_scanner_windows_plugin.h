#ifndef XUE_HUA_BARCODE_SCANNER_WINDOWS_PLUGIN_H_
#define XUE_HUA_BARCODE_SCANNER_WINDOWS_PLUGIN_H_

#include "windows_camera_capture.h"
#include "windows_camera_types.h"

#include <flutter/event_channel.h>
#include <flutter/event_sink.h>
#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/texture_registrar.h>

#include <deque>
#include <memory>
#include <mutex>

namespace xue_hua_barcode_scanner {

class XueHuaBarcodeScannerWindowsPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows* registrar);

  explicit XueHuaBarcodeScannerWindowsPlugin(
      flutter::PluginRegistrarWindows* registrar);
  ~XueHuaBarcodeScannerWindowsPlugin() override;

 private:
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue>& call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  bool IsOurTopLevelWindow(HWND hwnd) const;
  HWND PlatformWindow() const;
  void PostFrameToPlatformThread(CameraFramePacket packet);
  void DeliverPendingFrames();

  flutter::PluginRegistrarWindows* registrar_ = nullptr;
  int window_proc_delegate_id_ = 0;
  HWND view_hwnd_ = nullptr;
  std::mutex pending_frames_mutex_;
  std::deque<CameraFramePacket> pending_frames_;

  flutter::TextureRegistrar* texture_registrar_ = nullptr;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>
      method_channel_;
  std::unique_ptr<flutter::EventChannel<flutter::EncodableValue>>
      event_channel_;
  std::unique_ptr<flutter::EventSink<flutter::EncodableValue>> event_sink_;
  std::mutex sink_mutex_;

  std::unique_ptr<flutter::TextureVariant> texture_variant_;
  int64_t texture_id_ = -1;
  std::unique_ptr<WindowsCameraCapture> camera_capture_;
};

}  // namespace xue_hua_barcode_scanner

#endif  // XUE_HUA_BARCODE_SCANNER_WINDOWS_PLUGIN_H_
