package com.kurban.xue_hua_barcode_scanner;

import android.Manifest;
import android.app.Activity;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.graphics.ImageFormat;
import android.graphics.SurfaceTexture;
import android.hardware.camera2.CameraAccessException;
import android.hardware.camera2.CameraCaptureSession;
import android.hardware.camera2.CameraCharacteristics;
import android.hardware.camera2.CameraDevice;
import android.hardware.camera2.CameraManager;
import android.hardware.camera2.CaptureRequest;
import android.hardware.camera2.params.StreamConfigurationMap;
import android.media.Image;
import android.media.ImageReader;
import android.net.Uri;
import android.os.Handler;
import android.os.HandlerThread;
import android.os.Looper;
import android.os.SystemClock;
import android.util.Size;
import android.view.Surface;

import java.io.ByteArrayOutputStream;
import java.io.InputStream;
import java.nio.ByteBuffer;
import java.util.Arrays;
import java.util.HashMap;
import java.util.Map;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.embedding.engine.plugins.activity.ActivityAware;
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding;
import io.flutter.plugin.common.EventChannel;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.PluginRegistry;
import io.flutter.view.TextureRegistry;

public final class XueHuaBarcodeScannerPlugin implements
    FlutterPlugin,
    MethodChannel.MethodCallHandler,
    EventChannel.StreamHandler,
    ActivityAware,
    PluginRegistry.RequestPermissionsResultListener,
    PluginRegistry.ActivityResultListener {

  private static final int REQUEST_CAMERA_PERMISSION = 9201;
  private static final int REQUEST_PICK_IMAGE = 9202;

  private Context applicationContext;
  private Activity activity;
  private ActivityPluginBinding activityBinding;
  private TextureRegistry textureRegistry;
  private MethodChannel methodChannel;
  private EventChannel eventChannel;
  private EventChannel.EventSink eventSink;
  private final Handler mainHandler = new Handler(Looper.getMainLooper());

  private HandlerThread backgroundThread;
  private Handler backgroundHandler;

  private TextureRegistry.SurfaceTextureEntry surfaceTextureEntry;
  private Surface previewSurface;
  private ImageReader imageReader;
  private CameraDevice cameraDevice;
  private CameraCaptureSession captureSession;
  private CaptureRequest.Builder previewRequestBuilder;
  private boolean hasFlashAvailable = false;
  private int currentSensorOrientation = 90;
  private long lastFrameTimestampMs = 0L;

  private String pendingCameraFacing;
  private MethodChannel.Result pendingCameraResult;
  private MethodChannel.Result pendingGalleryResult;

  @Override
  public void onAttachedToEngine(FlutterPluginBinding binding) {
    applicationContext = binding.getApplicationContext();
    textureRegistry = binding.getTextureRegistry();

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
    stopCameraInternal(true);
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
    binding.addActivityResultListener(this);
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
      activityBinding.removeActivityResultListener(this);
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
      case "startCamera": {
        String facing = call.argument("facing");
        if (facing == null) {
          facing = "back";
        }
        handleStartCamera(facing, result);
        break;
      }
      case "stopCamera": {
        stopCameraInternal(false);
        result.success(null);
        break;
      }
      case "setTorch": {
        Boolean enabled = call.argument("enabled");
        boolean target = enabled != null && enabled;
        result.success(setTorchInternal(target));
        break;
      }
      case "pickImageFromGallery": {
        handlePickImageFromGallery(result);
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

  private void handleStartCamera(String facing, MethodChannel.Result result) {
    if (applicationContext == null) {
      result.error("NO_CONTEXT", "Application context is unavailable.", null);
      return;
    }
    if (applicationContext.checkSelfPermission(Manifest.permission.CAMERA)
        != PackageManager.PERMISSION_GRANTED) {
      if (activity != null) {
        pendingCameraFacing = facing;
        pendingCameraResult = result;
        activity.requestPermissions(
            new String[] {Manifest.permission.CAMERA},
            REQUEST_CAMERA_PERMISSION);
      } else {
        result.error(
            "CAMERA_PERMISSION_DENIED",
            "Camera permission is not granted and no Activity is attached.",
            null);
      }
      return;
    }
    openCameraForFacing(facing, result);
  }

  @Override
  public boolean onRequestPermissionsResult(
      int requestCode,
      String[] permissions,
      int[] grantResults) {
    if (requestCode != REQUEST_CAMERA_PERMISSION) {
      return false;
    }
    MethodChannel.Result callback = pendingCameraResult;
    String facing = pendingCameraFacing != null ? pendingCameraFacing : "back";
    pendingCameraResult = null;
    pendingCameraFacing = null;

    if (callback != null) {
      if (grantResults.length > 0 && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
        openCameraForFacing(facing, callback);
      } else {
        callback.error(
            "CAMERA_PERMISSION_DENIED",
            "Camera permission was denied by the user.",
            null);
      }
    }
    return true;
  }

  private void openCameraForFacing(String facing, MethodChannel.Result result) {
    stopCameraInternal(false);
    startBackgroundThread();

    CameraManager manager =
        (CameraManager) applicationContext.getSystemService(Context.CAMERA_SERVICE);
    if (manager == null) {
      result.error("NO_CAMERA_MANAGER", "CameraManager is unavailable.", null);
      return;
    }

    try {
      String[] cameraIds = manager.getCameraIdList();
      if (cameraIds == null || cameraIds.length == 0) {
        result.error("NO_CAMERA", "No camera devices found on this Android device.", null);
        return;
      }

      int desiredLens = CameraCharacteristics.LENS_FACING_BACK;
      if ("front".equalsIgnoreCase(facing)) {
        desiredLens = CameraCharacteristics.LENS_FACING_FRONT;
      } else if ("external".equalsIgnoreCase(facing)) {
        desiredLens = CameraCharacteristics.LENS_FACING_EXTERNAL;
      }

      String selectedCameraId = cameraIds[0];
      CameraCharacteristics selectedCharacteristics =
          manager.getCameraCharacteristics(selectedCameraId);
      for (String id : cameraIds) {
        CameraCharacteristics chars = manager.getCameraCharacteristics(id);
        Integer lensFacing = chars.get(CameraCharacteristics.LENS_FACING);
        if (lensFacing != null && lensFacing == desiredLens) {
          selectedCameraId = id;
          selectedCharacteristics = chars;
          break;
        }
      }

      Boolean flashInfo =
          selectedCharacteristics.get(CameraCharacteristics.FLASH_INFO_AVAILABLE);
      hasFlashAvailable = Boolean.TRUE.equals(flashInfo);
      Integer sensorOrientationObj =
          selectedCharacteristics.get(CameraCharacteristics.SENSOR_ORIENTATION);
      currentSensorOrientation = sensorOrientationObj != null ? sensorOrientationObj : 90;

      StreamConfigurationMap map = selectedCharacteristics.get(
          CameraCharacteristics.SCALER_STREAM_CONFIGURATION_MAP);
      Size chosenSize = chooseOptimalSize(
          map != null ? map.getOutputSizes(SurfaceTexture.class) : null,
          1280,
          720);

      if (surfaceTextureEntry == null) {
        surfaceTextureEntry = textureRegistry.createSurfaceTexture();
      }
      SurfaceTexture surfaceTexture = surfaceTextureEntry.surfaceTexture();
      surfaceTexture.setDefaultBufferSize(chosenSize.getWidth(), chosenSize.getHeight());
      previewSurface = new Surface(surfaceTexture);

      imageReader = ImageReader.newInstance(
          chosenSize.getWidth(),
          chosenSize.getHeight(),
          ImageFormat.YUV_420_888,
          2);
      imageReader.setOnImageAvailableListener(this::onImageAvailable, backgroundHandler);

      final int cameraCount = cameraIds.length;
      final int previewW = chosenSize.getWidth();
      final int previewH = chosenSize.getHeight();
      final long textureId = surfaceTextureEntry.id();

      manager.openCamera(
          selectedCameraId,
          new CameraDevice.StateCallback() {
            private boolean replied = false;

            @Override
            public void onOpened(CameraDevice device) {
              cameraDevice = device;
              createCaptureSession(device, new Runnable() {
                @Override
                public void run() {
                  if (!replied) {
                    replied = true;
                    Map<String, Object> reply = new HashMap<>();
                    reply.put("textureId", textureId);
                    reply.put("hasTorch", hasFlashAvailable);
                    reply.put("availableCameraCount", cameraCount);
                    reply.put("previewWidth", previewW);
                    reply.put("previewHeight", previewH);
                    reply.put("sensorOrientation", currentSensorOrientation);
                    mainHandler.post(() -> result.success(reply));
                  }
                }
              }, new Runnable() {
                @Override
                public void run() {
                  if (!replied) {
                    replied = true;
                    mainHandler.post(() -> result.error(
                        "SESSION_CONFIG_FAILED",
                        "Failed to configure camera capture session.",
                        null));
                  }
                }
              });
            }

            @Override
            public void onDisconnected(CameraDevice device) {
              device.close();
              if (cameraDevice == device) {
                cameraDevice = null;
              }
            }

            @Override
            public void onError(CameraDevice device, int error) {
              device.close();
              if (cameraDevice == device) {
                cameraDevice = null;
              }
              if (!replied) {
                replied = true;
                mainHandler.post(() -> result.error(
                    "CAMERA_OPEN_ERROR",
                    "CameraDevice error code: " + error,
                    null));
              }
            }
          },
          backgroundHandler);
    } catch (CameraAccessException | SecurityException e) {
      result.error("CAMERA_ACCESS_ERROR", e.getMessage(), null);
    }
  }

  private void createCaptureSession(
      CameraDevice device,
      Runnable onConfiguredCallback,
      Runnable onFailedCallback) {
    try {
      if (previewSurface == null || imageReader == null) {
        onFailedCallback.run();
        return;
      }
      previewRequestBuilder = device.createCaptureRequest(CameraDevice.TEMPLATE_PREVIEW);
      previewRequestBuilder.addTarget(previewSurface);
      previewRequestBuilder.addTarget(imageReader.getSurface());
      previewRequestBuilder.set(
          CaptureRequest.CONTROL_AF_MODE,
          CaptureRequest.CONTROL_AF_MODE_CONTINUOUS_PICTURE);
      previewRequestBuilder.set(
          CaptureRequest.CONTROL_AE_MODE,
          CaptureRequest.CONTROL_AE_MODE_ON);

      device.createCaptureSession(
          Arrays.asList(previewSurface, imageReader.getSurface()),
          new CameraCaptureSession.StateCallback() {
            @Override
            public void onConfigured(CameraCaptureSession session) {
              if (cameraDevice == null) {
                onFailedCallback.run();
                return;
              }
              captureSession = session;
              try {
                session.setRepeatingRequest(
                    previewRequestBuilder.build(),
                    null,
                    backgroundHandler);
                onConfiguredCallback.run();
              } catch (CameraAccessException e) {
                onFailedCallback.run();
              }
            }

            @Override
            public void onConfigureFailed(CameraCaptureSession session) {
              onFailedCallback.run();
            }
          },
          backgroundHandler);
    } catch (CameraAccessException e) {
      onFailedCallback.run();
    }
  }

  private void onImageAvailable(ImageReader reader) {
    Image image = null;
    try {
      image = reader.acquireLatestImage();
      if (image == null || eventSink == null) {
        return;
      }
      long now = SystemClock.elapsedRealtime();
      if (now - lastFrameTimestampMs < 140L) {
        return;
      }
      lastFrameTimestampMs = now;

      Image.Plane[] planes = image.getPlanes();
      if (planes == null || planes.length == 0) {
        return;
      }
      Image.Plane yPlane = planes[0];
      ByteBuffer buffer = yPlane.getBuffer();
      int rowStride = yPlane.getRowStride();
      int width = image.getWidth();
      int height = image.getHeight();
      int remaining = buffer.remaining();
      if (width <= 0 || height <= 0 || remaining <= 0) {
        return;
      }

      byte[] yBytes = new byte[remaining];
      buffer.get(yBytes);

      final Map<String, Object> packet = new HashMap<>();
      packet.put("bytes", yBytes);
      packet.put("width", width);
      packet.put("height", height);
      packet.put("rowStride", rowStride);
      packet.put("format", 0);
      packet.put("sensorOrientation", currentSensorOrientation);

      mainHandler.post(() -> {
        if (eventSink != null) {
          eventSink.success(packet);
        }
      });
    } catch (Exception ignored) {
    } finally {
      if (image != null) {
        image.close();
      }
    }
  }

  private boolean setTorchInternal(boolean enabled) {
    if (!hasFlashAvailable || captureSession == null || previewRequestBuilder == null) {
      return false;
    }
    try {
      previewRequestBuilder.set(
          CaptureRequest.FLASH_MODE,
          enabled ? CaptureRequest.FLASH_MODE_TORCH : CaptureRequest.FLASH_MODE_OFF);
      captureSession.setRepeatingRequest(
          previewRequestBuilder.build(),
          null,
          backgroundHandler);
      return true;
    } catch (CameraAccessException e) {
      return false;
    }
  }

  private void stopCameraInternal(boolean releaseTexture) {
    if (captureSession != null) {
      try {
        captureSession.close();
      } catch (Exception ignored) {
      }
      captureSession = null;
    }
    if (cameraDevice != null) {
      try {
        cameraDevice.close();
      } catch (Exception ignored) {
      }
      cameraDevice = null;
    }
    if (imageReader != null) {
      try {
        imageReader.close();
      } catch (Exception ignored) {
      }
      imageReader = null;
    }
    if (previewSurface != null) {
      try {
        previewSurface.release();
      } catch (Exception ignored) {
      }
      previewSurface = null;
    }
    if (releaseTexture && surfaceTextureEntry != null) {
      try {
        surfaceTextureEntry.release();
      } catch (Exception ignored) {
      }
      surfaceTextureEntry = null;
    }
    previewRequestBuilder = null;
    stopBackgroundThread();
  }

  private void startBackgroundThread() {
    if (backgroundThread != null) {
      return;
    }
    backgroundThread = new HandlerThread("XueHuaScannerCameraThread");
    backgroundThread.start();
    backgroundHandler = new Handler(backgroundThread.getLooper());
  }

  private void stopBackgroundThread() {
    if (backgroundThread == null) {
      return;
    }
    backgroundThread.quitSafely();
    try {
      backgroundThread.join(300);
    } catch (InterruptedException ignored) {
    }
    backgroundThread = null;
    backgroundHandler = null;
  }

  private static Size chooseOptimalSize(Size[] choices, int targetWidth, int targetHeight) {
    if (choices == null || choices.length == 0) {
      return new Size(targetWidth, targetHeight);
    }
    Size bestMatch = choices[0];
    int bestDiff = Integer.MAX_VALUE;
    for (Size size : choices) {
      int diff = Math.abs(size.getWidth() - targetWidth) + Math.abs(size.getHeight() - targetHeight);
      if (diff < bestDiff) {
        bestDiff = diff;
        bestMatch = size;
      }
    }
    return bestMatch;
  }

  private void handlePickImageFromGallery(MethodChannel.Result result) {
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
    if (resultCode != Activity.RESULT_OK || data == null || data.getData() == null) {
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
