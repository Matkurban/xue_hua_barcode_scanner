package com.kurban.xue_hua_barcode_scanner;

import android.Manifest;
import android.app.Activity;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.net.Uri;
import android.provider.Settings;

import io.flutter.plugin.common.MethodChannel;

/**
 * Handles runtime camera permission requests, rationale checks, and deep-linking
 * to the Android application permission settings screen.
 */
final class PermissionAndSettingsHelper {

  static final int REQUEST_CAMERA_PERMISSION = 9201;

  interface PermissionGrantedCallback {
    void onPermissionGranted(String facing, String cameraId, MethodChannel.Result result);
  }

  private final PermissionGrantedCallback grantedCallback;
  private String pendingCameraFacing;
  private String pendingCameraId;
  private MethodChannel.Result pendingCameraResult;

  PermissionAndSettingsHelper(PermissionGrantedCallback grantedCallback) {
    this.grantedCallback = grantedCallback;
  }

  boolean hasCameraPermission(Context context) {
    return context != null
        && context.checkSelfPermission(Manifest.permission.CAMERA)
            == PackageManager.PERMISSION_GRANTED;
  }

  void requestCameraPermission(
      Activity activity,
      String facing,
      String cameraId,
      MethodChannel.Result result) {
    if (activity == null) {
      result.error(
          "CAMERA_PERMISSION_DENIED",
          "Camera permission is not granted and no Activity is attached.",
          "denied");
      return;
    }
    pendingCameraFacing = facing;
    pendingCameraId = cameraId;
    pendingCameraResult = result;
    activity.requestPermissions(
        new String[] {Manifest.permission.CAMERA},
        REQUEST_CAMERA_PERMISSION);
  }

  boolean openAppSettings(Activity activity, Context applicationContext) {
    Context ctx = activity != null ? activity : applicationContext;
    if (ctx == null) {
      return false;
    }
    try {
      Intent intent = new Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS);
      intent.setData(Uri.fromParts("package", ctx.getPackageName(), null));
      intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
      ctx.startActivity(intent);
      return true;
    } catch (Exception e) {
      return false;
    }
  }

  boolean handlePermissionsResult(
      int requestCode,
      int[] grantResults,
      Activity activity) {
    if (requestCode != REQUEST_CAMERA_PERMISSION) {
      return false;
    }
    MethodChannel.Result callback = pendingCameraResult;
    String facing = pendingCameraFacing != null ? pendingCameraFacing : "back";
    String cameraId = pendingCameraId;
    pendingCameraResult = null;
    pendingCameraFacing = null;
    pendingCameraId = null;

    if (callback != null) {
      if (grantResults.length > 0 && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
        grantedCallback.onPermissionGranted(facing, cameraId, callback);
      } else {
        boolean showRationale =
            activity != null
                && activity.shouldShowRequestPermissionRationale(Manifest.permission.CAMERA);
        callback.error(
            "CAMERA_PERMISSION_DENIED",
            "Camera permission was denied by the user.",
            showRationale ? "denied" : "permanentlyDenied");
      }
    }
    return true;
  }
}
