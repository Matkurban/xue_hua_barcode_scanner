package com.kurban.xue_hua_barcode_scanner;

import android.app.Activity;
import android.content.Context;
import android.content.Intent;
import android.net.Uri;

import java.io.ByteArrayOutputStream;
import java.io.InputStream;

import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.PluginRegistry;

/**
 * Handles picking an image from the Android system document/gallery chooser and
 * reading its encoded bytes.
 */
final class GalleryImagePickerHandler implements PluginRegistry.ActivityResultListener {

  private static final int REQUEST_PICK_IMAGE = 9202;

  private Context applicationContext;
  private MethodChannel.Result pendingGalleryResult;

  void setApplicationContext(Context applicationContext) {
    this.applicationContext = applicationContext;
  }

  void pickImageFromGallery(Activity activity, MethodChannel.Result result) {
    if (activity == null) {
      result.success(null);
      return;
    }
    pendingGalleryResult = result;
    Intent intent = new Intent(Intent.ACTION_GET_CONTENT);
    intent.setType("image/*");
    intent.addCategory(Intent.CATEGORY_OPENABLE);
    activity.startActivityForResult(
        Intent.createChooser(intent, "选择图片"),
        REQUEST_PICK_IMAGE);
  }

  @Override
  public boolean onActivityResult(int requestCode, int resultCode, Intent data) {
    if (requestCode != REQUEST_PICK_IMAGE) {
      return false;
    }
    MethodChannel.Result callback = pendingGalleryResult;
    pendingGalleryResult = null;
    if (callback == null) {
      return true;
    }
    if (resultCode != Activity.RESULT_OK
        || data == null
        || data.getData() == null
        || applicationContext == null) {
      callback.success(null);
      return true;
    }
    Uri uri = data.getData();
    try (InputStream is = applicationContext.getContentResolver().openInputStream(uri)) {
      if (is == null) {
        callback.success(null);
        return true;
      }
      ByteArrayOutputStream buffer = new ByteArrayOutputStream();
      byte[] chunk = new byte[8192];
      int read;
      while ((read = is.read(chunk)) != -1) {
        buffer.write(chunk, 0, read);
      }
      callback.success(buffer.toByteArray());
    } catch (Exception e) {
      callback.success(null);
    }
    return true;
  }
}
