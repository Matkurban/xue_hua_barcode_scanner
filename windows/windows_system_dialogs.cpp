#include "windows_system_dialogs.h"

#ifndef NOMINMAX
#define NOMINMAX
#endif
#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif

#include <windows.h>
#include <commdlg.h>
#include <shellapi.h>

#pragma comment(lib, "Comdlg32.lib")
#pragma comment(lib, "Shell32.lib")

namespace xue_hua_barcode_scanner {

std::string WideToUtf8(const std::wstring& wstr) {
  if (wstr.empty()) return {};
  int size_needed = WideCharToMultiByte(
      CP_UTF8,
      0,
      wstr.data(),
      static_cast<int>(wstr.size()),
      nullptr,
      0,
      nullptr,
      nullptr);
  std::string result(size_needed, '\0');
  WideCharToMultiByte(
      CP_UTF8,
      0,
      wstr.data(),
      static_cast<int>(wstr.size()),
      result.data(),
      size_needed,
      nullptr,
      nullptr);
  return result;
}

std::string OpenImageFileDialog() {
  wchar_t file_name[MAX_PATH] = {0};
  OPENFILENAMEW ofn = {};
  ofn.lStructSize = sizeof(ofn);
  ofn.lpstrFile = file_name;
  ofn.nMaxFile = MAX_PATH;
  ofn.lpstrFilter =
      L"Image Files\0*.png;*.jpg;*.jpeg;*.bmp;*.webp\0All Files\0*.*\0";
  ofn.nFilterIndex = 1;
  ofn.Flags = OFN_PATHMUSTEXIST | OFN_FILEMUSTEXIST | OFN_NOCHANGEDIR;
  if (GetOpenFileNameW(&ofn) == TRUE) {
    return WideToUtf8(file_name);
  }
  return {};
}

bool OpenPrivacyWebcamSettings() {
  HINSTANCE res = ShellExecuteW(
      nullptr,
      L"open",
      L"ms-settings:privacy-webcam",
      nullptr,
      nullptr,
      SW_SHOWNORMAL);
  return reinterpret_cast<INT_PTR>(res) > 32;
}

}  // namespace xue_hua_barcode_scanner
