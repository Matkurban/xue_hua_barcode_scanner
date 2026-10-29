package com.kurban.xue_hua_barcode_scanner;

import android.app.Activity;
import android.content.Context;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.embedding.engine.plugins.activity.ActivityAware;
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding;
import io.flutter.plugin.common.EventChannel;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.PluginRegistry;

/**
 * Main Flutter plugin entry point on Android. Delegates camera session management,
 * permission handling, luminance extraction, and gallery picking to modular helpers.
 */
public final class XueHuaBarcodeScannerPlugin implements
    FlutterPlugin,
    MethodChannel.MethodCallHandler,
    EventChannel.StreamHandler,
    ActivityAware,
    PluginRegistry.RequestPermissionsResultListener {

  private Context applicationContext;
  private Activity activity;
  private ActivityPluginBinding activityBinding;
  private MethodChannel methodChannel;
  private EventChannel eventChannel;
  private EventChannel.EventSink eventSink;

  private final CameraSessionManager cameraSessionManager;
  private final PermissionAndSettingsHelper permissionHelper;
  private final GalleryImagePickerHandler galleryPickerHandler;

  public XueHuaBarcodeScannerPlugin() {
    this.cameraSessionManager = new CameraSessionManager(() -> eventSink);
    this.permissionHelper = new PermissionAndSettingsHelper(
        (facing, cameraId, result) -> cameraSessionManager.openCamera(facing, cameraId, result));
    this.galleryPickerHandler = new GalleryImagePickerHandler();
  }

  @Override
  public void onAttachedToEngine(FlutterPluginBinding binding) {
    applicationContext = binding.getApplicationContext();
    cameraSessionManager.attach(applicationContext, binding.getTextureRegistry());
    galleryPickerHandler.setApplicationContext(applicationContext);

    methodChannel = new MethodChannel(
        binding.getBinaryMessenger(),
        "com.kurban.xue_hua_barcode_scanner/methods");
    methodChannel.setMethodCallHandler(this);

    eventChannel = new EventChannel(
        binding.getBinaryMessenger(),
        "com.kurban.xue_hua_barcode_scanner/frames");
    eventChannel.setStreamHandler(this);
  }

  @Override
  public void onDetachedFromEngine(FlutterPluginBinding binding) {
    cameraSessionManager.stopCamera(true);
    if (methodChannel != null) {
      methodChannel.setMethodCallHandler(null);
      methodChannel = null;
    }
    if (eventChannel != null) {
      eventChannel.setStreamHandler(null);
      eventChannel = null;
    }
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
  public void onListen(Object arguments, EventChannel.EventSink events) {
    eventSink = events;
  }

  @Override
  public void onCancel(Object arguments) {
    eventSink = null;
  }

  @Override
  public void onMethodCall(MethodCall call, MethodChannel.Result result) {
    switch (call.method) {
      case "listCameras": {
        result.success(cameraSessionManager.listCameras());
        break;
      }
      case "startCamera": {
        String facing = call.argument("facing");
        if (facing == null) {
          facing = "back";
        }
        String cameraId = call.argument("cameraId");
        handleStartCamera(facing, cameraId, result);
        break;
      }
      case "stopCamera": {
        cameraSessionManager.stopCamera(false);
        result.success(null);
        break;
      }
      case "setTorch": {
        Boolean enabled = call.argument("enabled");
        boolean target = enabled != null && enabled;
        result.success(cameraSessionManager.setTorch(target));
        break;
      }
      case "openAppSettings": {
        result.success(permissionHelper.openAppSettings(activity, applicationContext));
        break;
      }
      case "pickImageFromGallery": {
        galleryPickerHandler.pickImageFromGallery(activity, result);
        break;
      }
      case "pickImageFilePath": {
        result.success(null);
        break;
      }
      default:
        result.notImplemented();
        break;
    }
  }

  private void handleStartCamera(
      String facing,
      String cameraId,
      MethodChannel.Result result) {
    if (applicationContext == null) {
      result.error("NO_CONTEXT", "Application context is unavailable.", null);
      return;
    }
    if (!permissionHelper.hasCameraPermission(applicationContext)) {
      permissionHelper.requestCameraPermission(activity, facing, cameraId, result);
      return;
    }
    cameraSessionManager.openCamera(facing, cameraId, result);
  }

  @Override
  public boolean onRequestPermissionsResult(
      int requestCode,
      String[] permissions,
      int[] grantResults) {
    return permissionHelper.handlePermissionsResult(requestCode, grantResults, activity);
  }
}
