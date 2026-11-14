package com.kurban.xue_hua_barcode_scanner;

import android.media.Image;
import java.nio.ByteBuffer;

/**
 * Extracts compact 1-channel 8-bit luminance (Y-plane) buffers from Android
 * {@link Image} frames ({@code YUV_420_888}) with row-stride normalization.
 */
final class FrameLuminanceExtractor {

  static final class LuminanceFrame {
    final byte[] bytes;
    final int width;
    final int height;
    final int rowStride;
    final int sensorOrientation;

    LuminanceFrame(
        byte[] bytes,
        int width,
        int height,
        int rowStride,
        int sensorOrientation) {
      this.bytes = bytes;
      this.width = width;
      this.height = height;
      this.rowStride = rowStride;
      this.sensorOrientation = sensorOrientation;
    }
  }

  private FrameLuminanceExtractor() {}

  static LuminanceFrame extractLuminanceFrame(Image image, int sensorOrientation) {
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

    return new LuminanceFrame(yBytes, width, height, width, sensorOrientation);
  }
}
