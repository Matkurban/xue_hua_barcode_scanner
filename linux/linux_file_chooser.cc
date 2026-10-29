#include "linux_file_chooser.h"

#include <gtk/gtk.h>

namespace xue_hua_barcode_scanner {

FlMethodResponse* PickImageFileWithGtkDialog(FlPluginRegistrar* registrar) {
  FlView* view = registrar != nullptr
                     ? fl_plugin_registrar_get_view(registrar)
                     : nullptr;
  GtkWindow* window =
      view != nullptr
          ? GTK_WINDOW(gtk_widget_get_toplevel(GTK_WIDGET(view)))
          : nullptr;
  GtkFileChooserNative* dialog = gtk_file_chooser_native_new(
      "选择图片",
      window,
      GTK_FILE_CHOOSER_ACTION_OPEN,
      "_打开",
      "_取消");
  gint res = gtk_native_dialog_run(GTK_NATIVE_DIALOG(dialog));
  FlMethodResponse* response = nullptr;
  if (res == GTK_RESPONSE_ACCEPT) {
    g_autofree gchar* filename =
        gtk_file_chooser_get_filename(GTK_FILE_CHOOSER(dialog));
    g_autoptr(FlValue) path_val =
        fl_value_new_string(filename != nullptr ? filename : "");
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(path_val));
  } else {
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
  }
  g_object_unref(dialog);
  return response;
}

}  // namespace xue_hua_barcode_scanner
