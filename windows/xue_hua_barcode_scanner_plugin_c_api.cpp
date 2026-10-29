#include "include/xue_hua_barcode_scanner/xue_hua_barcode_scanner_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "xue_hua_barcode_scanner_windows_plugin.h"

void XueHuaBarcodeScannerPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  xue_hua_barcode_scanner::XueHuaBarcodeScannerWindowsPlugin::
      RegisterWithRegistrar(
          flutter::PluginRegistrarManager::GetInstance()
              ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
