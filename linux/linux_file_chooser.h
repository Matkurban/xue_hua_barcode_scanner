#ifndef XUE_HUA_BARCODE_SCANNER_LINUX_FILE_CHOOSER_H_
#define XUE_HUA_BARCODE_SCANNER_LINUX_FILE_CHOOSER_H_

#include <flutter_linux/flutter_linux.h>

#include <cstdint>

namespace xue_hua_barcode_scanner {

/// Schedules a non-blocking GTK file chooser (`gtk_native_dialog_show`) on the
/// GLib main loop and completes the FFI pick-image request upon user response.
void PickImageFileWithGtkDialogAsync(
    FlPluginRegistrar* registrar,
    int64_t request_id);

}  // namespace xue_hua_barcode_scanner

#endif  // XUE_HUA_BARCODE_SCANNER_LINUX_FILE_CHOOSER_H_
