package com.kurban.xue_hua_barcode_scanner;

import android.Manifest;
import android.app.Activity;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.net.Uri;
import android.provider.Settings;

/**
 * Handles runtime camera permission requests, rationale checks, and deep-linking
 * to the Android application permission settings screen without MethodChannel.
 */
final class PermissionAndSettingsHelper {

  static final int REQUEST_CAMERA_PERMISSION = 9201;

  interface PermissionGrantedCallback {
    void onPermissionGranted(
        long requestId,
        long sessionGeneration,
        String facing,
        String cameraId);
  }

  private final PermissionGrantedCallback grantedCallback;
  private long pendingRequestId = 0L;
  private long pendingSessionGeneration = 0L;
  private String pendingCameraFacing;
  private String pendingCameraId;

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
      long requestId,
      long sessionGeneration,
      String facing,
      String cameraId) {
    if (activity == null) {
      XueHuaBarcodeScannerPlugin.nativeOnStartCameraResult(
          requestId,
          false,
          "CAMERA_PERMISSION_DENIED",
          "Camera permission is not granted and no Activity is attached.",
          "denied",
          -1L,
          false,
          false,
          0,
          null,
          facing != null ? facing : "back",
          0,
          0,
          0,
          null,
          null,
          null);
      return;
    }
    if (pendingRequestId != 0L) {
      XueHuaBarcodeScannerPlugin.nativeOnStartCameraResult(
          pendingRequestId,
          false,
          "CAMERA_PERMISSION_DENIED",
          "Superseded by a newer camera start request.",
          "denied",
          -1L,
          false,
          false,
          0,
          null,
          pendingCameraFacing != null ? pendingCameraFacing : "back",
          0,
          0,
          0,
          null,
          null,
          null);
    }
    pendingRequestId = requestId;
    pendingSessionGeneration = sessionGeneration;
    pendingCameraFacing = facing;
    pendingCameraId = cameraId;
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
    final long requestId = pendingRequestId;
    final long sessionGeneration = pendingSessionGeneration;
    final String facing = pendingCameraFacing != null ? pendingCameraFacing : "back";
    final String cameraId = pendingCameraId;
    pendingRequestId = 0L;
    pendingSessionGeneration = 0L;
    pendingCameraFacing = null;
    pendingCameraId = null;

    if (requestId != 0L) {
      if (grantResults.length > 0 && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
        grantedCallback.onPermissionGranted(requestId, sessionGeneration, facing, cameraId);
      } else {
        boolean showRationale =
            activity != null
                && activity.shouldShowRequestPermissionRationale(Manifest.permission.CAMERA);
        XueHuaBarcodeScannerPlugin.nativeOnStartCameraResult(
            requestId,
            false,
            "CAMERA_PERMISSION_DENIED",
            "Camera permission was denied by the user.",
            showRationale ? "denied" : "permanentlyDenied",
            -1L,
            false,
            false,
            0,
            null,
            facing,
            0,
            0,
            0,
            null,
            null,
            null);
      }
    }
    return true;
  }
}
