#ifndef XUE_HUA_BARCODE_SCANNER_LINUX_FILE_CHOOSER_H_
#define XUE_HUA_BARCODE_SCANNER_LINUX_FILE_CHOOSER_H_

#include <flutter_linux/flutter_linux.h>

namespace xue_hua_barcode_scanner {

/// Opens a native GTK file chooser dialog (`GtkFileChooserNative`) and returns
/// an `FlMethodResponse*` containing the selected image file path or `nullptr`.
FlMethodResponse* PickImageFileWithGtkDialog(FlPluginRegistrar* registrar);

}  // namespace xue_hua_barcode_scanner

#endif  // XUE_HUA_BARCODE_SCANNER_LINUX_FILE_CHOOSER_H_
