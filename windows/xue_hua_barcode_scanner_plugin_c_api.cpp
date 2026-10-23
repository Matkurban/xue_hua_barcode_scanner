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

#include <flutter/event_channel.h>
#include <flutter/event_sink.h>
#include <flutter/event_stream_handler_functions.h>
#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>
#include <flutter/texture_registrar.h>

#include <atomic>
#include <chrono>
#include <cstring>
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

namespace {

std::string WideToUtf8(const std::wstring& wstr) {
  if (wstr.empty()) return {};
  int size_needed = WideCharToMultiByte(
      CP_UTF8, 0, wstr.data(), static_cast<int>(wstr.size()), nullptr, 0, nullptr, nullptr);
  std::string result(size_needed, '\0');
  WideCharToMultiByte(
      CP_UTF8, 0, wstr.data(), static_cast<int>(wstr.size()), result.data(), size_needed, nullptr, nullptr);
  return result;
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
      : texture_registrar_(registrar->texture_registrar()) {
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
    if (method == "startCamera") {
      StartCameraCapture(std::move(result));
    } else if (method == "stopCamera") {
      StopCameraCapture();
      result->Success();
    } else if (method == "setTorch") {
      result->Success(flutter::EncodableValue(false));
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

  void StartCameraCapture(
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

    const UINT32 selected = device_index_ % count;
    device_index_ = (device_index_ + 1) % count;

    IMFMediaSource* media_source = nullptr;
    hr = devices[selected]->ActivateObject(IID_PPV_ARGS(&media_source));
    for (UINT32 i = 0; i < count; ++i) {
      devices[i]->Release();
    }
    CoTaskMemFree(devices);

    if (FAILED(hr) || media_source == nullptr) {
      result->Error("CAMERA_OPEN_FAILED", "Failed to activate Windows webcam.");
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
      result->Error("READER_CREATE_FAILED", "Failed to create MediaFoundation SourceReader.");
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
                std::lock_guard<std::mutex> sink_lock(sink_mutex_);
                if (event_sink_) {
                  std::vector<uint8_t> copy;
                  {
                    std::lock_guard<std::mutex> lock(frame_mutex_);
                    copy = front_rgba_;
                  }
                  flutter::EncodableMap packet;
                  packet[flutter::EncodableValue("bytes")] = flutter::EncodableValue(copy);
                  packet[flutter::EncodableValue("width")] =
                      flutter::EncodableValue(static_cast<int32_t>(width));
                  packet[flutter::EncodableValue("height")] =
                      flutter::EncodableValue(static_cast<int32_t>(height));
                  packet[flutter::EncodableValue("rowStride")] =
                      flutter::EncodableValue(static_cast<int32_t>(width * 4));
                  packet[flutter::EncodableValue("format")] = flutter::EncodableValue(1);
                  packet[flutter::EncodableValue("sensorOrientation")] =
                      flutter::EncodableValue(0);
                  event_sink_->Success(flutter::EncodableValue(packet));
                }
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
  UINT32 device_index_ = 0;
};

}  // namespace

void XueHuaBarcodeScannerPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  XueHuaBarcodeScannerWindowsPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
