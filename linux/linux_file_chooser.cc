#include "linux_file_chooser.h"

#include "scanner_host_ffi.h"

#include <gtk/gtk.h>

#include <memory>

namespace xue_hua_barcode_scanner {

namespace {

struct GtkPickInvokeContext {
  GWeakRef registrar_weak;
  int64_t request_id = 0;

  explicit GtkPickInvokeContext(FlPluginRegistrar* registrar, int64_t req_id)
      : request_id(req_id) {
    g_weak_ref_init(&registrar_weak, registrar);
  }

  ~GtkPickInvokeContext() { g_weak_ref_clear(&registrar_weak); }
};

struct GtkDialogResponseContext {
  int64_t request_id = 0;
};

void OnGtkFileChooserResponse(
    GtkNativeDialog* dialog,
    gint response_id,
    gpointer user_data) {
  std::unique_ptr<GtkDialogResponseContext> ctx(
      static_cast<GtkDialogResponseContext*>(user_data));

  if (response_id == GTK_RESPONSE_ACCEPT) {
    g_autofree gchar* filename =
        gtk_file_chooser_get_filename(GTK_FILE_CHOOSER(dialog));
    const bool has_path = filename != nullptr && filename[0] != '\0';
    xh_host_complete_pick_image(
        ctx->request_id,
        1,
        has_path ? 1 : 0,
        nullptr,
        0,
        has_path ? filename : nullptr,
        nullptr,
        nullptr);
  } else {
    xh_host_complete_pick_image(
        ctx->request_id, 1, 0, nullptr, 0, nullptr, nullptr, nullptr);
  }

  g_object_unref(dialog);
}

gboolean ShowGtkFileChooserOnMainThread(gpointer user_data) {
  std::unique_ptr<GtkPickInvokeContext> ctx(
      static_cast<GtkPickInvokeContext*>(user_data));

  gpointer reg_obj = g_weak_ref_get(&ctx->registrar_weak);
  if (reg_obj == nullptr) {
    xh_host_complete_pick_image(
        ctx->request_id, 1, 0, nullptr, 0, nullptr, nullptr, nullptr);
    return G_SOURCE_REMOVE;
  }
  FlPluginRegistrar* registrar = FL_PLUGIN_REGISTRAR(reg_obj);
  FlView* view = fl_plugin_registrar_get_view(registrar);
  GtkWidget* toplevel =
      view != nullptr ? gtk_widget_get_toplevel(GTK_WIDGET(view)) : nullptr;
  GtkWindow* window = (toplevel != nullptr &&
                       gtk_widget_is_toplevel(toplevel) &&
                       GTK_IS_WINDOW(toplevel))
                          ? GTK_WINDOW(toplevel)
                          : nullptr;
  g_object_unref(reg_obj);

  GtkFileChooserNative* dialog = gtk_file_chooser_native_new(
      "选择图片",
      window,
      GTK_FILE_CHOOSER_ACTION_OPEN,
      "_打开",
      "_取消");
  if (dialog == nullptr) {
    xh_host_complete_pick_image(
        ctx->request_id, 1, 0, nullptr, 0, nullptr, nullptr, nullptr);
    return G_SOURCE_REMOVE;
  }

  auto* response_ctx = new GtkDialogResponseContext{ctx->request_id};
  gtk_native_dialog_set_modal(GTK_NATIVE_DIALOG(dialog), TRUE);
  g_signal_connect(
      dialog,
      "response",
      G_CALLBACK(OnGtkFileChooserResponse),
      response_ctx);
  gtk_native_dialog_show(GTK_NATIVE_DIALOG(dialog));

  return G_SOURCE_REMOVE;
}

}  // namespace

void PickImageFileWithGtkDialogAsync(
    FlPluginRegistrar* registrar,
    int64_t request_id) {
  auto* ctx = new GtkPickInvokeContext(registrar, request_id);
  g_main_context_invoke_full(
      nullptr,
      G_PRIORITY_DEFAULT,
      ShowGtkFileChooserOnMainThread,
      ctx,
      nullptr);
}

}  // namespace xue_hua_barcode_scanner
