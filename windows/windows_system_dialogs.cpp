#include "windows_system_dialogs.h"

#include <commdlg.h>
#include <shellapi.h>

#ifdef _MSC_VER
#pragma comment(lib, "Comdlg32.lib")
#pragma comment(lib, "Shell32.lib")
#endif

namespace xue_hua_barcode_scanner {

std::string WideToUtf8(const std::wstring& wstr) {
  if (wstr.empty()) {
    return {};
  }
  const int size_needed = WideCharToMultiByte(
      CP_UTF8,
      0,
      wstr.data(),
      static_cast<int>(wstr.size()),
      nullptr,
      0,
      nullptr,
      nullptr);
  if (size_needed <= 0) {
    return {};
  }
  std::string result(static_cast<size_t>(size_needed), '\0');
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

std::string OpenImageFileDialog(HWND owner_hwnd) {
  wchar_t file_name[MAX_PATH] = {0};
  OPENFILENAMEW ofn = {};
  ofn.lStructSize = sizeof(ofn);
  ofn.hwndOwner = owner_hwnd;
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
