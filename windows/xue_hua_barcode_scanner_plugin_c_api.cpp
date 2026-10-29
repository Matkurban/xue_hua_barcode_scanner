#include "include/xue_hua_barcode_scanner/xue_hua_barcode_scanner_plugin_c_api.h"

#ifndef NOMINMAX
#define NOMINMAX
#endif
#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif

#include <windows.h>
#include <commdlg.h>
#include <mfapi.h>
#include <mfidl.h>
#include <mfreadwrite.h>
#include <shellapi.h>

#include <flutter/event_channel.h>
#include <flutter/event_sink.h>
#include <flutter/event_stream_handler_functions.h>
#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>
#include <flutter/texture_registrar.h>

#include <atomic>
#include <chrono>
#include <cstdint>
#include <cstring>
#include <deque>
#include <memory>
#include <mutex>
#include <string>
#include <thread>
#include <vector>

#pragma comment(lib, "mf.lib")
#pragma comment(lib, "mfplat.lib")
#pragma comment(lib, "mfreadwrite.lib")
#pragma comment(lib, "mfuuid.lib")
#pragma comment(lib, "Comdlg32.lib")
#pragma comment(lib, "Shell32.lib")

namespace {

// Posted to the top-level Flutter window. The runner pumps that window on the
// platform thread and forwards the message into plugin window-proc delegates,
// which is the same thread the Windows task runner uses for platform channels.
constexpr UINT kDeliverCameraFrameMessage = WM_APP + 0x485;

struct CameraFramePacket {
  std::vector<uint8_t> bytes;
  int32_t width = 0;
  int32_t height = 0;
  int32_t row_stride = 0;
  int32_t format = 0;
  int32_t sensor_orientation = 0;
};

struct VideoInput {
  std::string id;
  std::string label;
};

std::string WideToUtf8(const std::wstring& wstr) {
  if (wstr.empty()) return {};
  int size_needed = WideCharToMultiByte(
      CP_UTF8, 0, wstr.data(), static_cast<int>(wstr.size()), nullptr, 0, nullptr, nullptr);
  std::string result(size_needed, '\0');
  WideCharToMultiByte(
      CP_UTF8, 0, wstr.data(), static_cast<int>(wstr.size()), result.data(), size_needed, nullptr, nullptr);
  return result;
}

VideoInput ReadVideoInput(IMFActivate* device, UINT32 index) {
  VideoInput input;
  input.id = std::to_string(index);
  input.label = "摄像头 " + std::to_string(index + 1);
  if (device == nullptr) {
    return input;
  }
  WCHAR* link = nullptr;
  UINT32 link_len = 0;
  WCHAR* name = nullptr;
  UINT32 name_len = 0;
  if (SUCCEEDED(device->GetAllocatedString(
          MF_DEVSOURCE_ATTRIBUTE_SOURCE_TYPE_VIDCAP_SYMBOLIC_LINK,
          &link,
          &link_len)) &&
      link != nullptr) {
    input.id = WideToUtf8(std::wstring(link));
    CoTaskMemFree(link);
  }
  if (SUCCEEDED(device->GetAllocatedString(
          MF_DEVSOURCE_ATTRIBUTE_FRIENDLY_NAME, &name, &name_len)) &&
      name != nullptr) {
    const std::string friendly = WideToUtf8(std::wstring(name));
    CoTaskMemFree(name);
    if (!friendly.empty()) {
      input.label = friendly;
    }
  }
  return input;
}

flutter::EncodableList CameraListValue(const std::vector<VideoInput>& inputs) {
  flutter::EncodableList cameras;
  cameras.reserve(inputs.size());
  for (const VideoInput& input : inputs) {
    flutter::EncodableMap item;
    item[flutter::EncodableValue("id")] = flutter::EncodableValue(input.id);
    item[flutter::EncodableValue("label")] = flutter::EncodableValue(input.label);
    item[flutter::EncodableValue("facing")] = flutter::EncodableValue("external");
    cameras.push_back(flutter::EncodableValue(item));
  }
  return cameras;
}

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

class XueHuaBarcodeScannerWindowsPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows* registrar) {
    auto plugin = std::make_unique<XueHuaBarcodeScannerWindowsPlugin>(registrar);

    auto method_channel = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
        registrar->messenger(),
        "com.kurban.xue_hua_barcode_scanner/methods",
        &flutter::StandardMethodCodec::GetInstance());

    auto* raw_plugin = plugin.get();
    method_channel->SetMethodCallHandler(
        [raw_plugin](const auto& call, auto result) {
          raw_plugin->HandleMethodCall(call, std::move(result));
        });
    plugin->method_channel_ = std::move(method_channel);

    auto event_channel = std::make_unique<flutter::EventChannel<flutter::EncodableValue>>(
        registrar->messenger(),
        "com.kurban.xue_hua_barcode_scanner/frames",
        &flutter::StandardMethodCodec::GetInstance());
    event_channel->SetStreamHandler(
        std::make_unique<flutter::StreamHandlerFunctions<flutter::EncodableValue>>(
            [raw_plugin](
                const flutter::EncodableValue*,
                std::unique_ptr<flutter::EventSink<flutter::EncodableValue>>&& events)
                -> std::unique_ptr<flutter::StreamHandlerError<flutter::EncodableValue>> {
              std::lock_guard<std::mutex> lock(raw_plugin->sink_mutex_);
              raw_plugin->event_sink_ = std::move(events);
              return nullptr;
            },
            [raw_plugin](const flutter::EncodableValue*)
                -> std::unique_ptr<flutter::StreamHandlerError<flutter::EncodableValue>> {
              std::lock_guard<std::mutex> lock(raw_plugin->sink_mutex_);
              raw_plugin->event_sink_.reset();
              return nullptr;
            }));
    plugin->event_channel_ = std::move(event_channel);

    registrar->AddPlugin(std::move(plugin));
  }

  explicit XueHuaBarcodeScannerWindowsPlugin(flutter::PluginRegistrarWindows* registrar)
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
    pixel_buffer_.width = 1;
    pixel_buffer_.height = 1;
    front_rgba_.assign(4, 0);
    front_rgba_[3] = 255;
    pixel_buffer_.buffer = front_rgba_.data();

    texture_variant_ = std::make_unique<flutter::TextureVariant>(
        flutter::PixelBufferTexture(
            [this](size_t, size_t) -> const FlutterDesktopPixelBuffer* {
              std::lock_guard<std::mutex> lock(frame_mutex_);
              pixel_buffer_.buffer = front_rgba_.data();
              return &pixel_buffer_;
            }));
    texture_id_ = texture_registrar_->RegisterTexture(texture_variant_.get());
  }

  ~XueHuaBarcodeScannerWindowsPlugin() override {
    StopCameraCapture();
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

 private:
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue>& call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
    const std::string& method = call.method_name();
    if (method == "listCameras") {
      result->Success(flutter::EncodableValue(CameraListValue(EnumerateVideoInputs())));
    } else if (method == "startCamera") {
      StartCameraCapture(ArgumentString(call, "cameraId"), std::move(result));
    } else if (method == "stopCamera") {
      StopCameraCapture();
      result->Success();
    } else if (method == "setTorch") {
      result->Success(flutter::EncodableValue(false));
    } else if (method == "openAppSettings") {
      HINSTANCE res = ShellExecuteW(
          nullptr,
          L"open",
          L"ms-settings:privacy-webcam",
          nullptr,
          nullptr,
          SW_SHOWNORMAL);
      const bool opened = reinterpret_cast<INT_PTR>(res) > 32;
      result->Success(flutter::EncodableValue(opened));
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

  std::vector<VideoInput> EnumerateVideoInputs() {
    std::vector<VideoInput> inputs;
    IMFAttributes* attributes = nullptr;
    IMFActivate** devices = nullptr;
    UINT32 count = 0;
    HRESULT hr = MFCreateAttributes(&attributes, 1);
    if (SUCCEEDED(hr)) {
      hr = attributes->SetGUID(
          MF_DEVSOURCE_ATTRIBUTE_SOURCE_TYPE,
          MF_DEVSOURCE_ATTRIBUTE_SOURCE_TYPE_VIDCAP_GUID);
    }
    if (SUCCEEDED(hr)) {
      hr = MFEnumDeviceSources(attributes, &devices, &count);
    }
    if (attributes != nullptr) {
      attributes->Release();
    }
    if (FAILED(hr) || devices == nullptr) {
      if (devices != nullptr) {
        CoTaskMemFree(devices);
      }
      return inputs;
    }
    inputs.reserve(count);
    for (UINT32 i = 0; i < count; ++i) {
      inputs.push_back(ReadVideoInput(devices[i], i));
      devices[i]->Release();
    }
    CoTaskMemFree(devices);
    return inputs;
  }

  void StartCameraCapture(
      const std::string& camera_id,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
    StopCameraCapture();

    IMFAttributes* attributes = nullptr;
    IMFActivate** devices = nullptr;
    UINT32 count = 0;

    HRESULT hr = MFCreateAttributes(&attributes, 1);
    if (SUCCEEDED(hr)) {
      hr = attributes->SetGUID(
          MF_DEVSOURCE_ATTRIBUTE_SOURCE_TYPE,
          MF_DEVSOURCE_ATTRIBUTE_SOURCE_TYPE_VIDCAP_GUID);
    }
    if (SUCCEEDED(hr)) {
      hr = MFEnumDeviceSources(attributes, &devices, &count);
    }
    if (attributes != nullptr) {
      attributes->Release();
    }
    if (FAILED(hr) || count == 0 || devices == nullptr) {
      if (devices != nullptr) {
        CoTaskMemFree(devices);
      }
      result->Error("NO_CAMERA", "No webcam found on this Windows device.");
      return;
    }

    std::vector<VideoInput> inputs;
    inputs.reserve(count);
    for (UINT32 i = 0; i < count; ++i) {
      inputs.push_back(ReadVideoInput(devices[i], i));
    }
    UINT32 selected = 0;
    if (!camera_id.empty()) {
      for (UINT32 i = 0; i < count; ++i) {
        if (inputs[i].id == camera_id) {
          selected = i;
          break;
        }
      }
    }

    IMFMediaSource* media_source = nullptr;
    hr = devices[selected]->ActivateObject(IID_PPV_ARGS(&media_source));
    for (UINT32 i = 0; i < count; ++i) {
      devices[i]->Release();
    }
    CoTaskMemFree(devices);

    if (FAILED(hr) || media_source == nullptr) {
      if (hr == E_ACCESSDENIED) {
        result->Error(
            "CAMERA_PERMISSION_DENIED",
            "Camera access is denied by Windows privacy settings.",
            flutter::EncodableValue("permanentlyDenied"));
      } else {
        result->Error("CAMERA_OPEN_FAILED", "Failed to activate Windows webcam.");
      }
      return;
    }

    IMFAttributes* reader_attrs = nullptr;
    MFCreateAttributes(&reader_attrs, 1);
    if (reader_attrs != nullptr) {
      reader_attrs->SetUINT32(MF_SOURCE_READER_ENABLE_VIDEO_PROCESSING, TRUE);
    }

    IMFSourceReader* reader = nullptr;
    hr = MFCreateSourceReaderFromMediaSource(media_source, reader_attrs, &reader);
    if (reader_attrs != nullptr) {
      reader_attrs->Release();
    }
    media_source->Release();

    if (FAILED(hr) || reader == nullptr) {
      if (hr == E_ACCESSDENIED) {
        result->Error(
            "CAMERA_PERMISSION_DENIED",
            "Camera access is denied by Windows privacy settings.",
            flutter::EncodableValue("permanentlyDenied"));
      } else {
        result->Error("READER_CREATE_FAILED", "Failed to create MediaFoundation SourceReader.");
      }
      return;
    }

    IMFMediaType* media_type = nullptr;
    MFCreateMediaType(&media_type);
    if (media_type != nullptr) {
      media_type->SetGUID(MF_MT_MAJOR_TYPE, MFMediaType_Video);
      media_type->SetGUID(MF_MT_SUBTYPE, MFVideoFormat_RGB32);
      reader->SetCurrentMediaType(
          static_cast<DWORD>(MF_SOURCE_READER_FIRST_VIDEO_STREAM),
          nullptr,
          media_type);
      media_type->Release();
    }

    UINT32 width = 1280;
    UINT32 height = 720;
    IMFMediaType* current_type = nullptr;
    if (SUCCEEDED(reader->GetCurrentMediaType(
            static_cast<DWORD>(MF_SOURCE_READER_FIRST_VIDEO_STREAM),
            &current_type)) &&
        current_type != nullptr) {
      MFGetAttributeSize(current_type, MF_MT_FRAME_SIZE, &width, &height);
      current_type->Release();
    }

    running_ = true;
    capture_thread_ = std::thread([this, reader, width, height]() {
      CaptureLoop(reader, width, height);
    });

    flutter::EncodableMap reply;
    reply[flutter::EncodableValue("textureId")] = flutter::EncodableValue(texture_id_);
    reply[flutter::EncodableValue("hasTorch")] = flutter::EncodableValue(false);
    reply[flutter::EncodableValue("availableCameraCount")] =
        flutter::EncodableValue(static_cast<int32_t>(count));
    reply[flutter::EncodableValue("cameras")] =
        flutter::EncodableValue(CameraListValue(inputs));
    reply[flutter::EncodableValue("activeCameraId")] =
        flutter::EncodableValue(inputs[selected].id);
    reply[flutter::EncodableValue("cameraFacing")] =
        flutter::EncodableValue("external");
    reply[flutter::EncodableValue("previewWidth")] =
        flutter::EncodableValue(static_cast<int32_t>(width));
    reply[flutter::EncodableValue("previewHeight")] =
        flutter::EncodableValue(static_cast<int32_t>(height));
    reply[flutter::EncodableValue("sensorOrientation")] = flutter::EncodableValue(0);
    result->Success(flutter::EncodableValue(reply));
  }

  void CaptureLoop(IMFSourceReader* reader, UINT32 width, UINT32 height) {
    auto last_emit = std::chrono::steady_clock::now();
    while (running_) {
      DWORD stream_index = 0;
      DWORD flags = 0;
      LONGLONG timestamp = 0;
      IMFSample* sample = nullptr;
      HRESULT hr = reader->ReadSample(
          static_cast<DWORD>(MF_SOURCE_READER_FIRST_VIDEO_STREAM),
          0,
          &stream_index,
          &flags,
          &timestamp,
          &sample);
      if (FAILED(hr)) {
        break;
      }
      if (sample != nullptr) {
        IMFMediaBuffer* buffer = nullptr;
        if (SUCCEEDED(sample->ConvertToContiguousBuffer(&buffer)) && buffer != nullptr) {
          BYTE* data = nullptr;
          DWORD max_len = 0;
          DWORD cur_len = 0;
          if (SUCCEEDED(buffer->Lock(&data, &max_len, &cur_len)) && data != nullptr) {
            const size_t pixel_count = static_cast<size_t>(width) * height;
            if (cur_len >= pixel_count * 4) {
              {
                std::lock_guard<std::mutex> lock(frame_mutex_);
                front_rgba_.resize(pixel_count * 4);
                for (size_t i = 0; i < pixel_count; ++i) {
                  front_rgba_[i * 4 + 0] = data[i * 4 + 2];
                  front_rgba_[i * 4 + 1] = data[i * 4 + 1];
                  front_rgba_[i * 4 + 2] = data[i * 4 + 0];
                  front_rgba_[i * 4 + 3] = 255;
                }
                pixel_buffer_.width = width;
                pixel_buffer_.height = height;
                pixel_buffer_.buffer = front_rgba_.data();
              }
              if (texture_id_ >= 0 && texture_registrar_ != nullptr) {
                texture_registrar_->MarkTextureFrameAvailable(texture_id_);
              }

              auto now = std::chrono::steady_clock::now();
              if (std::chrono::duration_cast<std::chrono::milliseconds>(now - last_emit).count() >= 150) {
                last_emit = now;
                std::vector<uint8_t> luma(pixel_count);
                for (size_t i = 0; i < pixel_count; ++i) {
                  const uint32_t b = data[i * 4 + 0];
                  const uint32_t g = data[i * 4 + 1];
                  const uint32_t r = data[i * 4 + 2];
                  luma[i] = static_cast<uint8_t>((r * 77 + g * 150 + b * 29) >> 8);
                }
                CameraFramePacket packet;
                packet.bytes = std::move(luma);
                packet.width = static_cast<int32_t>(width);
                packet.height = static_cast<int32_t>(height);
                packet.row_stride = static_cast<int32_t>(width);
                packet.format = 0;
                packet.sensor_orientation = 0;
                // EventChannel::Success must run on the platform thread.
                PostFrameToPlatformThread(std::move(packet));
              }
            }
            buffer->Unlock();
          }
          buffer->Release();
        }
        sample->Release();
      }
    }
    reader->Release();
  }

  bool IsOurTopLevelWindow(HWND hwnd) const {
    if (view_hwnd_ == nullptr || hwnd == nullptr) {
      return false;
    }
    HWND top = GetAncestor(view_hwnd_, GA_ROOT);
    if (top == nullptr) {
      top = view_hwnd_;
    }
    return hwnd == top;
  }

  HWND PlatformWindow() const {
    if (view_hwnd_ == nullptr) {
      return nullptr;
    }
    HWND top = GetAncestor(view_hwnd_, GA_ROOT);
    return top != nullptr ? top : view_hwnd_;
  }

  void PostFrameToPlatformThread(CameraFramePacket packet) {
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

  void DeliverPendingFrames() {
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

  void StopCameraCapture() {
    running_ = false;
    if (capture_thread_.joinable()) {
      capture_thread_.join();
    }
  }

  std::string OpenImageFileDialog() {
    wchar_t file_name[MAX_PATH] = {0};
    OPENFILENAMEW ofn = {};
    ofn.lStructSize = sizeof(ofn);
    ofn.lpstrFile = file_name;
    ofn.nMaxFile = MAX_PATH;
    ofn.lpstrFilter = L"Image Files\0*.png;*.jpg;*.jpeg;*.bmp;*.webp\0All Files\0*.*\0";
    ofn.nFilterIndex = 1;
    ofn.Flags = OFN_PATHMUSTEXIST | OFN_FILEMUSTEXIST | OFN_NOCHANGEDIR;
    if (GetOpenFileNameW(&ofn) == TRUE) {
      return WideToUtf8(file_name);
    }
    return {};
  }

  flutter::PluginRegistrarWindows* registrar_ = nullptr;
  int window_proc_delegate_id_ = 0;
  HWND view_hwnd_ = nullptr;
  std::mutex pending_frames_mutex_;
  std::deque<CameraFramePacket> pending_frames_;

  flutter::TextureRegistrar* texture_registrar_ = nullptr;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> method_channel_;
  std::unique_ptr<flutter::EventChannel<flutter::EncodableValue>> event_channel_;
  std::unique_ptr<flutter::EventSink<flutter::EncodableValue>> event_sink_;
  std::mutex sink_mutex_;

  std::unique_ptr<flutter::TextureVariant> texture_variant_;
  int64_t texture_id_ = -1;
  std::mutex frame_mutex_;
  std::vector<uint8_t> front_rgba_;
  FlutterDesktopPixelBuffer pixel_buffer_{};

  std::atomic<bool> running_{false};
  std::thread capture_thread_;
};

}  // namespace

void XueHuaBarcodeScannerPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  XueHuaBarcodeScannerWindowsPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
