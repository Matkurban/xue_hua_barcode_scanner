package com.kurban.xue_hua_barcode_scanner;

import android.media.Image;
import java.nio.ByteBuffer;
import java.util.HashMap;
import java.util.Map;

/**
 * Extracts compact 1-channel 8-bit luminance (Y-plane) buffers from Android
 * {@link Image} frames ({@code YUV_420_888}) with row-stride normalization.
 */
final class FrameLuminanceExtractor {

  private FrameLuminanceExtractor() {}

  static Map<String, Object> extractFramePacket(Image image, int sensorOrientation) {
    Image.Plane[] planes = image.getPlanes();
    if (planes == null || planes.length == 0) {
      return null;
    }
    Image.Plane yPlane = planes[0];
    ByteBuffer buffer = yPlane.getBuffer();
    int rowStride = yPlane.getRowStride();
    int pixelStride = yPlane.getPixelStride();
    int width = image.getWidth();
    int height = image.getHeight();
    int remaining = buffer.remaining();
    if (width <= 0 || height <= 0 || remaining <= 0) {
      return null;
    }

    byte[] yBytes = new byte[width * height];
    if (pixelStride == 1 && rowStride == width && remaining >= width * height) {
      buffer.get(yBytes, 0, width * height);
    } else {
      for (int row = 0; row < height; row++) {
        int rowStart = row * rowStride;
        if (pixelStride == 1) {
          int copyLen = Math.min(width, remaining - rowStart);
          if (copyLen > 0) {
            buffer.position(rowStart);
            buffer.get(yBytes, row * width, copyLen);
          }
        } else {
          for (int col = 0; col < width; col++) {
            int idx = rowStart + col * pixelStride;
            if (idx < remaining) {
              yBytes[row * width + col] = buffer.get(idx);
            }
          }
        }
      }
    }

    Map<String, Object> packet = new HashMap<>();
    packet.put("bytes", yBytes);
    packet.put("width", width);
    packet.put("height", height);
    packet.put("rowStride", width);
    packet.put("format", 0);
    packet.put("sensorOrientation", sensorOrientation);
    return packet;
  }
}
