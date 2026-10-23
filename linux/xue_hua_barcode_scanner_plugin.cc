#include "include/xue_hua_barcode_scanner/xue_hua_barcode_scanner_plugin.h"

#include <flutter_linux/flutter_linux.h>
#include <gtk/gtk.h>

#include <cstring>
#include <string>

#define XUE_HUA_BARCODE_SCANNER_PLUGIN(obj) \
  (G_TYPE_CHECK_INSTANCE_CAST((obj), xue_hua_barcode_scanner_plugin_get_type(), \
                              XueHuaBarcodeScannerPlugin))

struct _XueHuaBarcodeScannerPlugin {
  GObject parent_instance;
  FlPluginRegistrar* registrar;
  FlMethodChannel* method_channel;
};

G_DEFINE_TYPE(XueHuaBarcodeScannerPlugin,
              xue_hua_barcode_scanner_plugin,
              g_object_get_type())

static void xue_hua_barcode_scanner_plugin_handle_method_call(
    XueHuaBarcodeScannerPlugin* self,
    FlMethodCall* method_call) {
  g_autoptr(FlMethodResponse) response = nullptr;
  const gchar* method = fl_method_call_get_name(method_call);

  if (strcmp(method, "startCamera") == 0) {
    response = FL_METHOD_RESPONSE(fl_method_error_response_new(
        "NO_CAMERA",
        "No V4L2 camera stream active.",
        nullptr));
  } else if (strcmp(method, "stopCamera") == 0) {
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
  } else if (strcmp(method, "setTorch") == 0) {
    g_autoptr(FlValue) res = fl_value_new_bool(FALSE);
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(res));
  } else if (strcmp(method, "pickImageFromGallery") == 0) {
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
  } else if (strcmp(method, "pickImageFilePath") == 0) {
    FlView* view = fl_plugin_registrar_get_view(self->registrar);
    GtkWindow* window = view != nullptr ? GTK_WINDOW(gtk_widget_get_toplevel(GTK_WIDGET(view))) : nullptr;
    GtkFileChooserNative* dialog = gtk_file_chooser_native_new(
        "选择图片",
        window,
        GTK_FILE_CHOOSER_ACTION_OPEN,
        "_打开",
        "_取消");
    gint res = gtk_native_dialog_run(GTK_NATIVE_DIALOG(dialog));
    if (res == GTK_RESPONSE_ACCEPT) {
      g_autofree gchar* filename = gtk_file_chooser_get_filename(GTK_FILE_CHOOSER(dialog));
      g_autoptr(FlValue) path_val = fl_value_new_string(filename != nullptr ? filename : "");
      response = FL_METHOD_RESPONSE(fl_method_success_response_new(path_val));
    } else {
      response = FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
    }
    g_object_unref(dialog);
  } else {
    response = FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
  }

  fl_method_call_respond(method_call, response, nullptr);
}

static void method_call_cb(FlMethodChannel* /*channel*/,
                           FlMethodCall* method_call,
                           gpointer user_data) {
  XueHuaBarcodeScannerPlugin* plugin = XUE_HUA_BARCODE_SCANNER_PLUGIN(user_data);
  xue_hua_barcode_scanner_plugin_handle_method_call(plugin, method_call);
}

static void xue_hua_barcode_scanner_plugin_dispose(GObject* object) {
  XueHuaBarcodeScannerPlugin* self = XUE_HUA_BARCODE_SCANNER_PLUGIN(object);
  g_clear_object(&self->method_channel);
  g_clear_object(&self->registrar);
  G_OBJECT_CLASS(xue_hua_barcode_scanner_plugin_parent_class)->dispose(object);
}

static void xue_hua_barcode_scanner_plugin_class_init(
    XueHuaBarcodeScannerPluginClass* klass) {
  G_OBJECT_CLASS(klass)->dispose = xue_hua_barcode_scanner_plugin_dispose;
}

static void xue_hua_barcode_scanner_plugin_init(
    XueHuaBarcodeScannerPlugin* /*self*/) {}

void xue_hua_barcode_scanner_plugin_register_with_registrar(
    FlPluginRegistrar* registrar) {
  XueHuaBarcodeScannerPlugin* plugin = XUE_HUA_BARCODE_SCANNER_PLUGIN(
      g_object_new(xue_hua_barcode_scanner_plugin_get_type(), nullptr));
  plugin->registrar = FL_PLUGIN_REGISTRAR(g_object_ref(registrar));

  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  plugin->method_channel = fl_method_channel_new(
      fl_plugin_registrar_get_messenger(registrar),
      "com.kurban.xue_hua_barcode_scanner/methods",
      FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(
      plugin->method_channel, method_call_cb, g_object_ref(plugin), g_object_unref);

  g_object_unref(plugin);
}
