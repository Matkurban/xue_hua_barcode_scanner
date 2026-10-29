#include "xue_hua_barcode_scanner_windows_plugin.h"

#include "windows_system_dialogs.h"

#include <flutter/event_stream_handler_functions.h>
#include <flutter/standard_method_codec.h>
#include <mfapi.h>

#include <optional>
#include <string>
#include <utility>

namespace xue_hua_barcode_scanner {

namespace {

std::string ArgumentString(
    const flutter::MethodCall<flutter::EncodableValue>& call,
    const char* key) {
  const auto* args = std::get_if<flutter::EncodableMap>(call.arguments());
  if (args == nullptr) {
    return {};
  }
  const auto it = args->find(flutter::EncodableValue(key));
  if (it == args->end()) {
    return {};
  }
  if (const auto* value = std::get_if<std::string>(&it->second)) {
    return *value;
  }
  return {};
}

}  // namespace

void XueHuaBarcodeScannerWindowsPlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows* registrar) {
  auto plugin = std::make_unique<XueHuaBarcodeScannerWindowsPlugin>(registrar);

  auto method_channel =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          registrar->messenger(),
          "com.kurban.xue_hua_barcode_scanner/methods",
          &flutter::StandardMethodCodec::GetInstance());

  auto* raw_plugin = plugin.get();
  method_channel->SetMethodCallHandler(
      [raw_plugin](const auto& call, auto result) {
        raw_plugin->HandleMethodCall(call, std::move(result));
      });
  plugin->method_channel_ = std::move(method_channel);

  auto event_channel =
      std::make_unique<flutter::EventChannel<flutter::EncodableValue>>(
          registrar->messenger(),
          "com.kurban.xue_hua_barcode_scanner/frames",
          &flutter::StandardMethodCodec::GetInstance());
  event_channel->SetStreamHandler(
      std::make_unique<flutter::StreamHandlerFunctions<flutter::EncodableValue>>(
          [raw_plugin](
              const flutter::EncodableValue*,
              std::unique_ptr<flutter::EventSink<flutter::EncodableValue>>&&
                  events)
              -> std::unique_ptr<
                  flutter::StreamHandlerError<flutter::EncodableValue>> {
            std::lock_guard<std::mutex> lock(raw_plugin->sink_mutex_);
            raw_plugin->event_sink_ = std::move(events);
            return nullptr;
          },
          [raw_plugin](const flutter::EncodableValue*)
              -> std::unique_ptr<
                  flutter::StreamHandlerError<flutter::EncodableValue>> {
            std::lock_guard<std::mutex> lock(raw_plugin->sink_mutex_);
            raw_plugin->event_sink_.reset();
            return nullptr;
          }));
  plugin->event_channel_ = std::move(event_channel);

  registrar->AddPlugin(std::move(plugin));
}

XueHuaBarcodeScannerWindowsPlugin::XueHuaBarcodeScannerWindowsPlugin(
    flutter::PluginRegistrarWindows* registrar)
    : registrar_(registrar),
      texture_registrar_(registrar->texture_registrar()) {
  if (flutter::FlutterView* view = registrar->GetView()) {
    view_hwnd_ = view->GetNativeWindow();
  }
  window_proc_delegate_id_ = registrar_->RegisterTopLevelWindowProcDelegate(
      [this](HWND hwnd, UINT message, WPARAM wparam, LPARAM lparam)
          -> std::optional<LRESULT> {
        (void)wparam;
        (void)lparam;
        if (message != kDeliverCameraFrameMessage) {
          return std::nullopt;
        }
        if (!IsOurTopLevelWindow(hwnd)) {
          return std::nullopt;
        }
        DeliverPendingFrames();
        return 0;
      });
  MFStartup(MF_VERSION);

  texture_variant_ = std::make_unique<flutter::TextureVariant>(
      flutter::PixelBufferTexture(
          [this](size_t, size_t) -> const FlutterDesktopPixelBuffer* {
            return camera_capture_ != nullptr
                       ? camera_capture_->CopyPixelBuffer()
                       : nullptr;
          }));
  texture_id_ = texture_registrar_->RegisterTexture(texture_variant_.get());

  camera_capture_ = std::make_unique<WindowsCameraCapture>(
      texture_registrar_,
      texture_id_,
      [this](CameraFramePacket packet) {
        PostFrameToPlatformThread(std::move(packet));
      });
}

XueHuaBarcodeScannerWindowsPlugin::~XueHuaBarcodeScannerWindowsPlugin() {
  if (camera_capture_ != nullptr) {
    camera_capture_->StopCapture();
    camera_capture_.reset();
  }
  if (registrar_ != nullptr && window_proc_delegate_id_ != 0) {
    registrar_->UnregisterTopLevelWindowProcDelegate(window_proc_delegate_id_);
    window_proc_delegate_id_ = 0;
  }
  if (texture_id_ >= 0 && texture_registrar_ != nullptr) {
    texture_registrar_->UnregisterTexture(texture_id_);
    texture_id_ = -1;
  }
  MFShutdown();
}

void XueHuaBarcodeScannerWindowsPlugin::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue>& call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  const std::string& method = call.method_name();
  if (method == "listCameras") {
    result->Success(flutter::EncodableValue(
        WindowsCameraCapture::CameraListValue(
            camera_capture_->EnumerateVideoInputs())));
  } else if (method == "startCamera") {
    camera_capture_->StartCapture(
        ArgumentString(call, "cameraId"), std::move(result));
  } else if (method == "stopCamera") {
    camera_capture_->StopCapture();
    result->Success();
  } else if (method == "setTorch") {
    result->Success(flutter::EncodableValue(false));
  } else if (method == "openAppSettings") {
    result->Success(flutter::EncodableValue(OpenPrivacyWebcamSettings()));
  } else if (method == "pickImageFromGallery") {
    result->Success();
  } else if (method == "pickImageFilePath") {
    std::string path = OpenImageFileDialog();
    if (path.empty()) {
      result->Success();
    } else {
      result->Success(flutter::EncodableValue(path));
    }
  } else {
    result->NotImplemented();
  }
}

bool XueHuaBarcodeScannerWindowsPlugin::IsOurTopLevelWindow(HWND hwnd) const {
  if (view_hwnd_ == nullptr || hwnd == nullptr) {
    return false;
  }
  HWND top = GetAncestor(view_hwnd_, GA_ROOT);
  if (top == nullptr) {
    top = view_hwnd_;
  }
  return hwnd == top;
}

HWND XueHuaBarcodeScannerWindowsPlugin::PlatformWindow() const {
  if (view_hwnd_ == nullptr) {
    return nullptr;
  }
  HWND top = GetAncestor(view_hwnd_, GA_ROOT);
  return top != nullptr ? top : view_hwnd_;
}

void XueHuaBarcodeScannerWindowsPlugin::PostFrameToPlatformThread(
    CameraFramePacket packet) {
  HWND target = PlatformWindow();
  if (target == nullptr) {
    return;
  }
  {
    std::lock_guard<std::mutex> lock(pending_frames_mutex_);
    pending_frames_.push_back(std::move(packet));
    if (pending_frames_.size() > 2) {
      pending_frames_.pop_front();
    }
  }
  if (PostMessage(target, kDeliverCameraFrameMessage, 0, 0) == FALSE) {
    std::lock_guard<std::mutex> lock(pending_frames_mutex_);
    pending_frames_.clear();
  }
}

void XueHuaBarcodeScannerWindowsPlugin::DeliverPendingFrames() {
  std::deque<CameraFramePacket> frames;
  {
    std::lock_guard<std::mutex> lock(pending_frames_mutex_);
    frames.swap(pending_frames_);
  }
  std::lock_guard<std::mutex> sink_lock(sink_mutex_);
  if (!event_sink_) {
    return;
  }
  for (CameraFramePacket& frame : frames) {
    flutter::EncodableMap packet;
    packet[flutter::EncodableValue("bytes")] =
        flutter::EncodableValue(frame.bytes);
    packet[flutter::EncodableValue("width")] =
        flutter::EncodableValue(frame.width);
    packet[flutter::EncodableValue("height")] =
        flutter::EncodableValue(frame.height);
    packet[flutter::EncodableValue("rowStride")] =
        flutter::EncodableValue(frame.row_stride);
    packet[flutter::EncodableValue("format")] =
        flutter::EncodableValue(frame.format);
    packet[flutter::EncodableValue("sensorOrientation")] =
        flutter::EncodableValue(frame.sensor_orientation);
    event_sink_->Success(flutter::EncodableValue(packet));
  }
}

}  // namespace xue_hua_barcode_scanner
