#ifndef XUE_HUA_BARCODE_SCANNER_WINDOWS_SYSTEM_DIALOGS_H_
#define XUE_HUA_BARCODE_SCANNER_WINDOWS_SYSTEM_DIALOGS_H_

#ifndef NOMINMAX
#define NOMINMAX
#endif
#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif

#include <windows.h>

#include <string>

namespace xue_hua_barcode_scanner {

/// Converts a wide UTF-16 string into a UTF-8 std::string.
std::string WideToUtf8(const std::wstring& wstr);

/// Opens the native Win32 file chooser (`GetOpenFileNameW`) for picking an image file.
std::string OpenImageFileDialog(HWND owner_hwnd);

/// Opens the Windows System Settings Camera privacy page (`ms-settings:privacy-webcam`).
bool OpenPrivacyWebcamSettings();

}  // namespace xue_hua_barcode_scanner

#endif  // XUE_HUA_BARCODE_SCANNER_WINDOWS_SYSTEM_DIALOGS_H_
