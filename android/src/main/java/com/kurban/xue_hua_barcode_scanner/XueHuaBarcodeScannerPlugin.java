package com.kurban.xue_hua_barcode_scanner;

import android.app.Activity;
import android.content.Context;
import android.os.Handler;
import android.os.Looper;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.embedding.engine.plugins.activity.ActivityAware;
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding;
import io.flutter.plugin.common.PluginRegistry;

/**
 * Pure FFI/JNI Android host for the barcode scanner plugin. Owns Flutter texture
 * registration, Activity permission/gallery lifecycle, and dispatches native FFI
 * requests onto Android's main Looper while emitting camera frames directly from
 * the background capture thread through JNI.
 */
public final class XueHuaBarcodeScannerPlugin implements
    FlutterPlugin,
    ActivityAware,
    PluginRegistry.RequestPermissionsResultListener {

  static {
    System.loadLibrary("xue_hua_barcode_scanner");
  }

  private final Handler mainHandler = new Handler(Looper.getMainLooper());
  private volatile boolean attachedToEngine = false;

  private Context applicationContext;
  private Activity activity;
  private ActivityPluginBinding activityBinding;

  private final CameraSessionManager cameraSessionManager;
  private final PermissionAndSettingsHelper permissionHelper;
  private final GalleryImagePickerHandler galleryPickerHandler;

  public XueHuaBarcodeScannerPlugin() {
    this.cameraSessionManager = new CameraSessionManager();
    this.permissionHelper = new PermissionAndSettingsHelper(
        (requestId, sessionGeneration, facing, cameraId) ->
            cameraSessionManager.openCamera(requestId, sessionGeneration, facing, cameraId));
    this.galleryPickerHandler = new GalleryImagePickerHandler();
  }

  @Override
  public void onAttachedToEngine(FlutterPluginBinding binding) {
    applicationContext = binding.getApplicationContext();
    cameraSessionManager.attach(applicationContext, binding.getTextureRegistry());
    galleryPickerHandler.setApplicationContext(applicationContext);
    attachedToEngine = true;
    nativeAttachHost();
  }

  @Override
  public void onDetachedFromEngine(FlutterPluginBinding binding) {
    attachedToEngine = false;
    nativeDetachHost();
    cameraSessionManager.stopCamera(true);
    detachActivityListeners();
    galleryPickerHandler.setApplicationContext(null);
    applicationContext = null;
  }

  @Override
  public void onAttachedToActivity(ActivityPluginBinding binding) {
    activity = binding.getActivity();
    activityBinding = binding;
    binding.addRequestPermissionsResultListener(this);
    binding.addActivityResultListener(galleryPickerHandler);
  }

  @Override
  public void onDetachedFromActivityForConfigChanges() {
    detachActivityListeners();
  }

  @Override
  public void onReattachedToActivityForConfigChanges(ActivityPluginBinding binding) {
    onAttachedToActivity(binding);
  }

  @Override
  public void onDetachedFromActivity() {
    detachActivityListeners();
  }

  private void detachActivityListeners() {
    if (activityBinding != null) {
      activityBinding.removeRequestPermissionsResultListener(this);
      activityBinding.removeActivityResultListener(galleryPickerHandler);
      activityBinding = null;
    }
    activity = null;
  }

  @Override
  public boolean onRequestPermissionsResult(
      int requestCode,
      String[] permissions,
      int[] grantResults) {
    return permissionHelper.handlePermissionsResult(requestCode, grantResults, activity);
  }

  // Invoked from src/scanner_host_jni.cpp on FFI/Dart caller threads.

  @SuppressWarnings("unused")
  void fromFfiListCameras(final long requestId) {
    mainHandler.post(() -> {
      if (!attachedToEngine) {
        nativeOnCameraListResult(
            requestId, true, null, null, new String[0], new String[0], new String[0]);
        return;
      }
      cameraSessionManager.listCameras(requestId);
    });
  }

  @SuppressWarnings("unused")
  void fromFfiStartCamera(
      final long requestId,
      final long sessionGeneration,
      final String facing,
      final String cameraId) {
    mainHandler.post(() -> {
      final String requestedFacing = facing != null ? facing : "back";
      if (!attachedToEngine || applicationContext == null) {
        nativeOnStartCameraResult(
            requestId,
            false,
            "NO_CONTEXT",
            "Application context is unavailable.",
            null,
            -1L,
            false,
            false,
            0,
            null,
            requestedFacing,
            0,
            0,
            0,
            null,
            null,
            null);
        return;
      }
      if (!permissionHelper.hasCameraPermission(applicationContext)) {
        permissionHelper.requestCameraPermission(
            activity, requestId, sessionGeneration, requestedFacing, cameraId);
        return;
      }
      cameraSessionManager.openCamera(requestId, sessionGeneration, requestedFacing, cameraId);
    });
  }

  @SuppressWarnings("unused")
  void fromFfiStopCamera(final long requestId) {
    mainHandler.post(() -> {
      cameraSessionManager.stopCamera(false);
      nativeOnBoolResult(requestId, true, true, null, null);
    });
  }

  @SuppressWarnings("unused")
  void fromFfiSetTorch(final long requestId, final boolean enabled) {
    mainHandler.post(() -> {
      boolean ok = attachedToEngine && cameraSessionManager.setTorch(enabled);
      nativeOnBoolResult(requestId, true, ok, null, null);
    });
  }

  @SuppressWarnings("unused")
  void fromFfiOpenAppSettings(final long requestId) {
    mainHandler.post(() -> {
      boolean opened =
          attachedToEngine && permissionHelper.openAppSettings(activity, applicationContext);
      nativeOnBoolResult(requestId, true, opened, null, null);
    });
  }

  @SuppressWarnings("unused")
  void fromFfiPickImage(final long requestId, final boolean preferFilePath) {
    mainHandler.post(() -> {
      if (!attachedToEngine || preferFilePath) {
        nativeOnPickImageResult(requestId, true, false, null, null, null, null);
        return;
      }
      galleryPickerHandler.pickImageFromGallery(activity, requestId);
    });
  }

  @SuppressWarnings("unused")
  void fromFfiSetFrameStreamPaused(final boolean paused) {
    cameraSessionManager.setFrameStreamPaused(paused);
  }

  // Native JNI bridge declarations (implemented in src/scanner_host_jni.cpp).

  private native void nativeAttachHost();

  private native void nativeDetachHost();

  static native void nativeOnCameraListResult(
      long requestId,
      boolean ok,
      String errorCode,
      String errorMessage,
      String[] ids,
      String[] labels,
      String[] facings);

  static native void nativeOnStartCameraResult(
      long requestId,
      boolean ok,
      String errorCode,
      String errorMessage,
      String errorDetails,
      long textureId,
      boolean hasTorch,
      boolean torchEnabled,
      int availableCameraCount,
      String activeCameraId,
      String cameraFacing,
      int previewWidth,
      int previewHeight,
      int sensorOrientation,
      String[] ids,
      String[] labels,
      String[] facings);

  static native void nativeOnBoolResult(
      long requestId,
      boolean ok,
      boolean value,
      String errorCode,
      String errorMessage);

  static native void nativeOnPickImageResult(
      long requestId,
      boolean ok,
      boolean hasData,
      byte[] bytes,
      String filePath,
      String errorCode,
      String errorMessage);

  static native void nativeOnCameraFrame(
      long sessionGeneration,
      byte[] bytes,
      int byteLength,
      int width,
      int height,
      int rowStride,
      int format,
      int sensorOrientation);
}
