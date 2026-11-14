package com.kurban.xue_hua_barcode_scanner;

import android.app.Activity;
import android.content.Context;
import android.content.Intent;
import android.net.Uri;

import java.io.ByteArrayOutputStream;
import java.io.InputStream;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

import io.flutter.plugin.common.PluginRegistry;

/**
 * Handles picking an image from the Android system document/gallery chooser and
 * reading its encoded bytes on a background executor without blocking UI.
 */
final class GalleryImagePickerHandler implements PluginRegistry.ActivityResultListener {

  private static final int REQUEST_PICK_IMAGE = 9202;

  private final ExecutorService ioExecutor = Executors.newSingleThreadExecutor();
  private Context applicationContext;
  private long pendingRequestId = 0L;

  void setApplicationContext(Context applicationContext) {
    this.applicationContext = applicationContext;
  }

  void pickImageFromGallery(Activity activity, long requestId) {
    if (activity == null) {
      XueHuaBarcodeScannerPlugin.nativeOnPickImageResult(
          requestId, true, false, null, null, null, null);
      return;
    }
    if (pendingRequestId != 0L) {
      XueHuaBarcodeScannerPlugin.nativeOnPickImageResult(
          pendingRequestId, true, false, null, null, null, null);
    }
    pendingRequestId = requestId;
    try {
      Intent intent = new Intent(Intent.ACTION_GET_CONTENT);
      intent.setType("image/*");
      intent.addCategory(Intent.CATEGORY_OPENABLE);
      activity.startActivityForResult(
          Intent.createChooser(intent, "选择图片"),
          REQUEST_PICK_IMAGE);
    } catch (Exception e) {
      pendingRequestId = 0L;
      XueHuaBarcodeScannerPlugin.nativeOnPickImageResult(
          requestId, true, false, null, null, null, null);
    }
  }

  @Override
  public boolean onActivityResult(int requestCode, int resultCode, Intent data) {
    if (requestCode != REQUEST_PICK_IMAGE) {
      return false;
    }
    final long requestId = pendingRequestId;
    pendingRequestId = 0L;
    if (requestId == 0L) {
      return true;
    }
    final Context ctx = applicationContext;
    if (resultCode != Activity.RESULT_OK
        || data == null
        || data.getData() == null
        || ctx == null) {
      XueHuaBarcodeScannerPlugin.nativeOnPickImageResult(
          requestId, true, false, null, null, null, null);
      return true;
    }
    final Uri uri = data.getData();
    ioExecutor.execute(() -> {
      try (InputStream is = ctx.getContentResolver().openInputStream(uri)) {
        if (is == null) {
          XueHuaBarcodeScannerPlugin.nativeOnPickImageResult(
              requestId, true, false, null, null, null, null);
          return;
        }
        ByteArrayOutputStream buffer = new ByteArrayOutputStream();
        byte[] chunk = new byte[8192];
        int read;
        while ((read = is.read(chunk)) != -1) {
          buffer.write(chunk, 0, read);
        }
        byte[] bytes = buffer.toByteArray();
        XueHuaBarcodeScannerPlugin.nativeOnPickImageResult(
            requestId,
            true,
            bytes.length > 0,
            bytes.length > 0 ? bytes : null,
            null,
            null,
            null);
      } catch (Exception e) {
        XueHuaBarcodeScannerPlugin.nativeOnPickImageResult(
            requestId, true, false, null, null, null, null);
      }
    });
    return true;
  }
}
