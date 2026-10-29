#include "windows_camera_capture.h"

#include "windows_system_dialogs.h"

#include <mfapi.h>
#include <mfidl.h>
#include <mfreadwrite.h>

#include <chrono>
#include <utility>

#pragma comment(lib, "mf.lib")
#pragma comment(lib, "mfplat.lib")
#pragma comment(lib, "mfreadwrite.lib")
#pragma comment(lib, "mfuuid.lib")

namespace xue_hua_barcode_scanner {

namespace {

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

}  // namespace

WindowsCameraCapture::WindowsCameraCapture(
    flutter::TextureRegistrar* texture_registrar,
    int64_t texture_id,
    FrameReadyCallback on_frame_ready)
    : texture_registrar_(texture_registrar),
      texture_id_(texture_id),
      on_frame_ready_(std::move(on_frame_ready)) {
  pixel_buffer_.width = 1;
  pixel_buffer_.height = 1;
  front_rgba_.assign(4, 0);
  front_rgba_[3] = 255;
  pixel_buffer_.buffer = front_rgba_.data();
}

WindowsCameraCapture::~WindowsCameraCapture() {
  StopCapture();
}

const FlutterDesktopPixelBuffer* WindowsCameraCapture::CopyPixelBuffer() {
  std::lock_guard<std::mutex> lock(frame_mutex_);
  pixel_buffer_.buffer = front_rgba_.data();
  return &pixel_buffer_;
}

flutter::EncodableList WindowsCameraCapture::CameraListValue(
    const std::vector<VideoInput>& inputs) {
  flutter::EncodableList cameras;
  cameras.reserve(inputs.size());
  for (const VideoInput& input : inputs) {
    flutter::EncodableMap item;
    item[flutter::EncodableValue("id")] = flutter::EncodableValue(input.id);
    item[flutter::EncodableValue("label")] =
        flutter::EncodableValue(input.label);
    item[flutter::EncodableValue("facing")] =
        flutter::EncodableValue("external");
    cameras.push_back(flutter::EncodableValue(item));
  }
  return cameras;
}

std::vector<VideoInput> WindowsCameraCapture::EnumerateVideoInputs() {
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

void WindowsCameraCapture::StartCapture(
    const std::string& camera_id,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  StopCapture();

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
      result->Error(
          "READER_CREATE_FAILED",
          "Failed to create MediaFoundation SourceReader.");
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
  reply[flutter::EncodableValue("textureId")] =
      flutter::EncodableValue(texture_id_);
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
  reply[flutter::EncodableValue("sensorOrientation")] =
      flutter::EncodableValue(0);
  result->Success(flutter::EncodableValue(reply));
}

void WindowsCameraCapture::CaptureLoop(
    IMFSourceReader* reader,
    UINT32 width,
    UINT32 height) {
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
      if (SUCCEEDED(sample->ConvertToContiguousBuffer(&buffer)) &&
          buffer != nullptr) {
        BYTE* data = nullptr;
        DWORD max_len = 0;
        DWORD cur_len = 0;
        if (SUCCEEDED(buffer->Lock(&data, &max_len, &cur_len)) &&
            data != nullptr) {
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
            if (std::chrono::duration_cast<std::chrono::milliseconds>(
                    now - last_emit)
                    .count() >= 150) {
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
              if (on_frame_ready_) {
                on_frame_ready_(std::move(packet));
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

void WindowsCameraCapture::StopCapture() {
  running_ = false;
  if (capture_thread_.joinable()) {
    capture_thread_.join();
  }
}

}  // namespace xue_hua_barcode_scanner
