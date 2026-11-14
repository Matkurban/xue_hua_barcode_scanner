package com.kurban.xue_hua_barcode_scanner;

import android.content.Context;
import android.graphics.ImageFormat;
import android.graphics.SurfaceTexture;
import android.hardware.camera2.CameraAccessException;
import android.hardware.camera2.CameraCaptureSession;
import android.hardware.camera2.CameraCharacteristics;
import android.hardware.camera2.CameraDevice;
import android.hardware.camera2.CameraManager;
import android.hardware.camera2.CaptureRequest;
import android.hardware.camera2.params.OutputConfiguration;
import android.hardware.camera2.params.SessionConfiguration;
import android.hardware.camera2.params.StreamConfigurationMap;
import android.media.Image;
import android.media.ImageReader;
import android.os.Build;
import android.os.Handler;
import android.os.HandlerThread;
import android.os.SystemClock;
import android.util.Size;
import android.view.Surface;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import io.flutter.view.TextureRegistry;

/**
 * Manages the Android Camera2 session lifecycle, device enumeration, SurfaceTexture
 * preview rendering, hardware flashlight control, and direct FFI/JNI frame emission.
 */
final class CameraSessionManager {

  private static final int PIXEL_FORMAT_LUM = 0; // C_PIXEL_FORMAT_LUM

  private static final class CameraDescriptions {
    final String[] ids;
    final String[] labels;
    final String[] facings;

    CameraDescriptions(String[] ids, String[] labels, String[] facings) {
      this.ids = ids;
      this.labels = labels;
      this.facings = facings;
    }
  }

  private Context applicationContext;
  private TextureRegistry textureRegistry;
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
  private volatile long activeSessionGeneration = 0L;
  private volatile boolean frameStreamPaused = false;

  CameraSessionManager() {}

  void attach(Context context, TextureRegistry registry) {
    this.applicationContext = context;
    this.textureRegistry = registry;
  }

  void setFrameStreamPaused(boolean paused) {
    this.frameStreamPaused = paused;
  }

  void listCameras(long requestId) {
    if (applicationContext == null) {
      XueHuaBarcodeScannerPlugin.nativeOnCameraListResult(
          requestId, true, null, null, new String[0], new String[0], new String[0]);
      return;
    }
    CameraManager manager =
        (CameraManager) applicationContext.getSystemService(Context.CAMERA_SERVICE);
    if (manager == null) {
      XueHuaBarcodeScannerPlugin.nativeOnCameraListResult(
          requestId, true, null, null, new String[0], new String[0], new String[0]);
      return;
    }
    try {
      String[] cameraIds = manager.getCameraIdList();
      if (cameraIds == null || cameraIds.length == 0) {
        XueHuaBarcodeScannerPlugin.nativeOnCameraListResult(
            requestId, true, null, null, new String[0], new String[0], new String[0]);
        return;
      }
      CameraDescriptions desc = describeCameras(manager, cameraIds);
      XueHuaBarcodeScannerPlugin.nativeOnCameraListResult(
          requestId, true, null, null, desc.ids, desc.labels, desc.facings);
    } catch (CameraAccessException | SecurityException e) {
      XueHuaBarcodeScannerPlugin.nativeOnCameraListResult(
          requestId, true, null, null, new String[0], new String[0], new String[0]);
    }
  }

  void openCamera(long requestId, long sessionGeneration, String facing, String cameraId) {
    stopCamera(false);
    activeSessionGeneration = sessionGeneration;
    frameStreamPaused = false;
    startBackgroundThread();

    final String requestedFacing = facing != null ? facing : "back";

    if (applicationContext == null || textureRegistry == null) {
      XueHuaBarcodeScannerPlugin.nativeOnStartCameraResult(
          requestId,
          false,
          "NO_CONTEXT",
          "Application context or TextureRegistry is unavailable.",
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

    CameraManager manager =
        (CameraManager) applicationContext.getSystemService(Context.CAMERA_SERVICE);
    if (manager == null) {
      XueHuaBarcodeScannerPlugin.nativeOnStartCameraResult(
          requestId,
          false,
          "NO_CAMERA_MANAGER",
          "CameraManager is unavailable.",
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

    try {
      String[] cameraIds = manager.getCameraIdList();
      if (cameraIds == null || cameraIds.length == 0) {
        XueHuaBarcodeScannerPlugin.nativeOnStartCameraResult(
            requestId,
            false,
            "NO_CAMERA",
            "No camera devices found on this Android device.",
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

      final CameraDescriptions cameras = describeCameras(manager, cameraIds);
      int desiredLens = CameraCharacteristics.LENS_FACING_BACK;
      if ("front".equalsIgnoreCase(requestedFacing)) {
        desiredLens = CameraCharacteristics.LENS_FACING_FRONT;
      } else if ("external".equalsIgnoreCase(requestedFacing)) {
        desiredLens = CameraCharacteristics.LENS_FACING_EXTERNAL;
      }

      String selectedCameraId = null;
      CameraCharacteristics selectedCharacteristics = null;
      if (cameraId != null && !cameraId.isEmpty()) {
        for (String id : cameraIds) {
          if (cameraId.equals(id)) {
            selectedCameraId = id;
            selectedCharacteristics = manager.getCameraCharacteristics(id);
            break;
          }
        }
      }
      if (selectedCameraId == null) {
        for (String id : cameraIds) {
          CameraCharacteristics chars = manager.getCameraCharacteristics(id);
          Integer lensFacing = chars.get(CameraCharacteristics.LENS_FACING);
          if (lensFacing != null && lensFacing == desiredLens) {
            selectedCameraId = id;
            selectedCharacteristics = chars;
            break;
          }
        }
      }
      if (selectedCameraId == null) {
        selectedCameraId = cameraIds[0];
        selectedCharacteristics = manager.getCameraCharacteristics(selectedCameraId);
      }
      final String activeCameraId = selectedCameraId;
      final String activeFacing = facingName(
          selectedCharacteristics.get(CameraCharacteristics.LENS_FACING));

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
      final boolean hasTorch = hasFlashAvailable;
      final int sensorOrient = currentSensorOrientation;

      manager.openCamera(
          selectedCameraId,
          new CameraDevice.StateCallback() {
            private boolean replied = false;

            @Override
            public void onOpened(CameraDevice device) {
              cameraDevice = device;
              createCaptureSession(
                  device,
                  () -> {
                    if (!replied) {
                      replied = true;
                      XueHuaBarcodeScannerPlugin.nativeOnStartCameraResult(
                          requestId,
                          true,
                          null,
                          null,
                          null,
                          textureId,
                          hasTorch,
                          false,
                          cameraCount,
                          activeCameraId,
                          activeFacing,
                          previewW,
                          previewH,
                          sensorOrient,
                          cameras.ids,
                          cameras.labels,
                          cameras.facings);
                    }
                  },
                  () -> {
                    if (!replied) {
                      replied = true;
                      XueHuaBarcodeScannerPlugin.nativeOnStartCameraResult(
                          requestId,
                          false,
                          "SESSION_CONFIG_FAILED",
                          "Failed to configure camera capture session.",
                          null,
                          -1L,
                          false,
                          false,
                          0,
                          null,
                          activeFacing,
                          0,
                          0,
                          0,
                          null,
                          null,
                          null);
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
                XueHuaBarcodeScannerPlugin.nativeOnStartCameraResult(
                    requestId,
                    false,
                    "CAMERA_OPEN_ERROR",
                    "CameraDevice error code: " + error,
                    null,
                    -1L,
                    false,
                    false,
                    0,
                    null,
                    activeFacing,
                    0,
                    0,
                    0,
                    null,
                    null,
                    null);
              }
            }
          },
          backgroundHandler);
    } catch (CameraAccessException | SecurityException e) {
      XueHuaBarcodeScannerPlugin.nativeOnStartCameraResult(
          requestId,
          false,
          "CAMERA_ACCESS_ERROR",
          e.getMessage(),
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
    }
  }

  boolean setTorch(boolean enabled) {
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

  void stopCamera(boolean releaseTexture) {
    activeSessionGeneration = 0L;
    hasFlashAvailable = false;
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

  private void onImageAvailable(ImageReader reader) {
    Image image = null;
    try {
      image = reader.acquireLatestImage();
      final long generation = activeSessionGeneration;
      if (image == null || generation == 0L || frameStreamPaused) {
        return;
      }
      long now = SystemClock.elapsedRealtime();
      if (now - lastFrameTimestampMs < 140L) {
        return;
      }
      lastFrameTimestampMs = now;

      final FrameLuminanceExtractor.LuminanceFrame frame =
          FrameLuminanceExtractor.extractLuminanceFrame(image, currentSensorOrientation);
      if (frame == null) {
        return;
      }

      XueHuaBarcodeScannerPlugin.nativeOnCameraFrame(
          generation,
          frame.bytes,
          frame.bytes.length,
          frame.width,
          frame.height,
          frame.rowStride,
          PIXEL_FORMAT_LUM,
          frame.sensorOrientation);
    } catch (Exception ignored) {
    } finally {
      if (image != null) {
        image.close();
      }
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

      CameraCaptureSession.StateCallback stateCallback =
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
          };

      if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
        OutputConfiguration previewOutput = new OutputConfiguration(previewSurface);
        OutputConfiguration imageOutput = new OutputConfiguration(imageReader.getSurface());
        SessionConfiguration sessionConfig = new SessionConfiguration(
            SessionConfiguration.SESSION_REGULAR,
            Arrays.asList(previewOutput, imageOutput),
            command -> {
              Handler handler = backgroundHandler;
              if (handler != null) {
                handler.post(command);
              }
            },
            stateCallback);
        device.createCaptureSession(sessionConfig);
      } else {
        createLegacyCaptureSession(device, stateCallback);
      }
    } catch (CameraAccessException e) {
      onFailedCallback.run();
    }
  }

  @SuppressWarnings("deprecation")
  private void createLegacyCaptureSession(
      CameraDevice device,
      CameraCaptureSession.StateCallback stateCallback) throws CameraAccessException {
    device.createCaptureSession(
        Arrays.asList(previewSurface, imageReader.getSurface()),
        stateCallback,
        backgroundHandler);
  }

  private CameraDescriptions describeCameras(
      CameraManager manager,
      String[] cameraIds) throws CameraAccessException {
    List<String> facings = new ArrayList<>();
    List<String> baseLabels = new ArrayList<>();
    Map<String, Integer> labelCounts = new HashMap<>();
    for (String id : cameraIds) {
      CameraCharacteristics chars = manager.getCameraCharacteristics(id);
      String facing = facingName(chars.get(CameraCharacteristics.LENS_FACING));
      String baseLabel = baseLabelForFacing(facing);
      facings.add(facing);
      baseLabels.add(baseLabel);
      Integer count = labelCounts.get(baseLabel);
      labelCounts.put(baseLabel, count == null ? 1 : count + 1);
    }
    Map<String, Integer> seen = new HashMap<>();
    String[] ids = new String[cameraIds.length];
    String[] labels = new String[cameraIds.length];
    String[] facingArray = new String[cameraIds.length];
    for (int i = 0; i < cameraIds.length; i++) {
      String baseLabel = baseLabels.get(i);
      int ordinal = seen.containsKey(baseLabel) ? seen.get(baseLabel) + 1 : 1;
      seen.put(baseLabel, ordinal);
      Integer total = labelCounts.get(baseLabel);
      String label = total != null && total > 1 ? baseLabel + " " + ordinal : baseLabel;
      ids[i] = cameraIds[i];
      labels[i] = label;
      facingArray[i] = facings.get(i);
    }
    return new CameraDescriptions(ids, labels, facingArray);
  }

  private static String facingName(Integer lensFacing) {
    if (lensFacing != null && lensFacing == CameraCharacteristics.LENS_FACING_FRONT) {
      return "front";
    }
    if (lensFacing != null && lensFacing == CameraCharacteristics.LENS_FACING_EXTERNAL) {
      return "external";
    }
    return "back";
  }

  private static String baseLabelForFacing(String facing) {
    if ("front".equals(facing)) {
      return "前置相机";
    }
    if ("external".equals(facing)) {
      return "外接相机";
    }
    return "后置相机";
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
}
