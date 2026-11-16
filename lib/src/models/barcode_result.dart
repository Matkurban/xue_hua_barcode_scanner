import 'dart:typed_data';
import 'dart:ui' show Offset, Rect, Size;

import 'package:flutter/foundation.dart' show listEquals;

import 'barcode_enums.dart';

/// Validation callback used to verify whether a decoded [BarcodeResult] meets
/// business rules (e.g. specific URL prefix, format, or payload structure).
///
/// Returning `false` marks the scan state with `hasValidationError = true` and
/// turns the scanner cutout border red.
typedef XueHuaBarcodeValidator = bool Function(BarcodeResult result);

/// Immutable result of decoding a single barcode / 2D code.
class BarcodeResult {
  /// Creates a [BarcodeResult] instance.
  const BarcodeResult({
    required this.text,
    required this.rawBytes,
    required this.cornerPoints,
    this.format = BarcodeFormat.qrCode,
    this.isValid = true,
    this.frameSize,
  });

  /// UTF-8 decoded text payload.
  final String text;

  /// Raw byte payload of the decoded symbol.
  final Uint8List rawBytes;

  /// Four localization corner points `[topLeft, topRight, bottomRight, bottomLeft]`
  /// in source image coordinates (or normalized `[0..1]` if [frameSize] is null).
  final List<Offset> cornerPoints;

  /// Recognized barcode symbology format.
  final BarcodeFormat format;

  /// Whether the symbol checksum and payload are valid.
  final bool isValid;

  /// Optional dimensions of the source image frame from which [cornerPoints] were measured.
  final Size? frameSize;

  /// Computes the geometric center of [cornerPoints] for drawing target anchor highlights.
  Offset get centerPoint {
    if (cornerPoints.isEmpty) {
      return Offset.zero;
    }
    double sumX = 0;
    double sumY = 0;
    for (final point in cornerPoints) {
      sumX += point.dx;
      sumY += point.dy;
    }
    return Offset(sumX / cornerPoints.length, sumY / cornerPoints.length);
  }

  /// Computes the axis-aligned bounding box enclosing [cornerPoints].
  Rect get boundingBox {
    if (cornerPoints.isEmpty) {
      return Rect.zero;
    }
    double minX = cornerPoints.first.dx;
    double maxX = cornerPoints.first.dx;
    double minY = cornerPoints.first.dy;
    double maxY = cornerPoints.first.dy;
    for (final point in cornerPoints.skip(1)) {
      if (point.dx < minX) minX = point.dx;
      if (point.dx > maxX) maxX = point.dx;
      if (point.dy < minY) minY = point.dy;
      if (point.dy > maxY) maxY = point.dy;
    }
    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  /// Maps [cornerPoints] from source camera frame coordinates (handling sensor
  /// rotation and `BoxFit.cover` cropping) into widget viewport coordinates.
  List<Offset> mapCornersToViewport({
    required Size viewportSize,
    int sensorOrientation = 0,
    bool isFrontCamera = false,
  }) {
    final Size srcSize = frameSize ?? viewportSize;
    if (srcSize.width <= 0 || srcSize.height <= 0 || cornerPoints.isEmpty) {
      return cornerPoints;
    }

    final bool swapDimensions =
        sensorOrientation == 90 || sensorOrientation == 270;
    final double orientedW = swapDimensions ? srcSize.height : srcSize.width;
    final double orientedH = swapDimensions ? srcSize.width : srcSize.height;

    final double scaleX = viewportSize.width / orientedW;
    final double scaleY = viewportSize.height / orientedH;
    final double scale = scaleX > scaleY ? scaleX : scaleY;

    final double scaledW = orientedW * scale;
    final double scaledH = orientedH * scale;
    final double offsetX = (viewportSize.width - scaledW) / 2.0;
    final double offsetY = (viewportSize.height - scaledH) / 2.0;

    return cornerPoints
        .map((pt) {
          double rx = pt.dx;
          double ry = pt.dy;
          switch (sensorOrientation % 360) {
            case 90:
              rx = srcSize.height - pt.dy;
              ry = pt.dx;
              break;
            case 180:
              rx = srcSize.width - pt.dx;
              ry = srcSize.height - pt.dy;
              break;
            case 270:
              rx = pt.dy;
              ry = srcSize.width - pt.dx;
              break;
            default:
              break;
          }
          if (isFrontCamera) {
            rx = orientedW - rx;
          }
          return Offset(rx * scale + offsetX, ry * scale + offsetY);
        })
        .toList(growable: false);
  }

  /// Maps the geometric center of [cornerPoints] into widget viewport coordinates.
  Offset mapCenterToViewport({
    required Size viewportSize,
    int sensorOrientation = 0,
    bool isFrontCamera = false,
  }) {
    final List<Offset> mapped = mapCornersToViewport(
      viewportSize: viewportSize,
      sensorOrientation: sensorOrientation,
      isFrontCamera: isFrontCamera,
    );
    if (mapped.isEmpty) {
      return Offset(viewportSize.width / 2.0, viewportSize.height / 2.0);
    }
    double sumX = 0;
    double sumY = 0;
    for (final Offset pt in mapped) {
      sumX += pt.dx;
      sumY += pt.dy;
    }
    return Offset(sumX / mapped.length, sumY / mapped.length);
  }

  /// Maps the axis-aligned bounding box of [cornerPoints] into widget viewport coordinates.
  Rect mapBoundingBoxToViewport({
    required Size viewportSize,
    int sensorOrientation = 0,
    bool isFrontCamera = false,
  }) {
    final List<Offset> mapped = mapCornersToViewport(
      viewportSize: viewportSize,
      sensorOrientation: sensorOrientation,
      isFrontCamera: isFrontCamera,
    );
    if (mapped.isEmpty) {
      return Rect.zero;
    }
    double minX = mapped.first.dx;
    double maxX = mapped.first.dx;
    double minY = mapped.first.dy;
    double maxY = mapped.first.dy;
    for (final Offset pt in mapped.skip(1)) {
      if (pt.dx < minX) minX = pt.dx;
      if (pt.dx > maxX) maxX = pt.dx;
      if (pt.dy < minY) minY = pt.dy;
      if (pt.dy > maxY) maxY = pt.dy;
    }
    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  /// Builds a [BarcodeMarkerInfo] containing viewport-mapped geometry for this barcode.
  BarcodeMarkerInfo toMarkerInfo({
    required int index,
    required int totalCount,
    required Size viewportSize,
    int sensorOrientation = 0,
    bool isFrontCamera = false,
    bool isMultiSelectMode = false,
  }) {
    final List<Offset> mappedCorners = mapCornersToViewport(
      viewportSize: viewportSize,
      sensorOrientation: sensorOrientation,
      isFrontCamera: isFrontCamera,
    );
    Offset mappedCenter;
    Rect mappedBounds;
    if (mappedCorners.isEmpty) {
      mappedCenter = Offset(viewportSize.width / 2.0, viewportSize.height / 2.0);
      mappedBounds = Rect.fromCenter(
        center: mappedCenter,
        width: 48.0,
        height: 48.0,
      );
    } else {
      double sumX = 0;
      double sumY = 0;
      double minX = mappedCorners.first.dx;
      double maxX = mappedCorners.first.dx;
      double minY = mappedCorners.first.dy;
      double maxY = mappedCorners.first.dy;
      for (final Offset pt in mappedCorners) {
        sumX += pt.dx;
        sumY += pt.dy;
        if (pt.dx < minX) minX = pt.dx;
        if (pt.dx > maxX) maxX = pt.dx;
        if (pt.dy < minY) minY = pt.dy;
        if (pt.dy > maxY) maxY = pt.dy;
      }
      mappedCenter = Offset(
        sumX / mappedCorners.length,
        sumY / mappedCorners.length,
      );
      mappedBounds = Rect.fromLTRB(minX, minY, maxX, maxY);
    }
    return BarcodeMarkerInfo(
      result: this,
      index: index,
      totalCount: totalCount,
      center: mappedCenter,
      boundingBox: mappedBounds,
      cornerPoints: mappedCorners,
      viewportSize: viewportSize,
      isMultiSelectMode: isMultiSelectMode,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BarcodeResult &&
        other.text == text &&
        other.format == format &&
        other.isValid == isValid &&
        other.frameSize == frameSize &&
        listEquals(other.cornerPoints, cornerPoints);
  }

  @override
  int get hashCode => Object.hash(
    text,
    format,
    isValid,
    frameSize,
    Object.hashAll(cornerPoints),
  );

  @override
  String toString() =>
      'BarcodeResult(text: "$text", format: ${format.displayName}, '
      'isValid: $isValid, cornerPoints: $cornerPoints)';
}

/// Encapsulates a detected [BarcodeResult] along with its exact mapped viewport
/// coordinates (`center`, `boundingBox`, `cornerPoints`) for rendering positioned
/// target anchor widgets or custom overlay components.
class BarcodeMarkerInfo {
  /// Creates a [BarcodeMarkerInfo].
  const BarcodeMarkerInfo({
    required this.result,
    required this.index,
    required this.totalCount,
    required this.center,
    required this.boundingBox,
    required this.cornerPoints,
    required this.viewportSize,
    required this.isMultiSelectMode,
  });

  /// The decoded barcode payload and metadata.
  final BarcodeResult result;

  /// Zero-based index of this barcode in the detected list (`0 .. totalCount - 1`).
  final int index;

  /// Total number of valid barcodes detected in the current frame.
  final int totalCount;

  /// Geometric center of the barcode mapped into widget viewport coordinates.
  final Offset center;

  /// Axis-aligned bounding rectangle of the barcode mapped into widget viewport coordinates.
  final Rect boundingBox;

  /// Four corner points of the barcode mapped into widget viewport coordinates.
  final List<Offset> cornerPoints;

  /// Dimensions of the scanner viewport.
  final Size viewportSize;

  /// `true` when the scanner has paused on multiple barcodes and is waiting for
  /// the user to manually tap/select one.
  final bool isMultiSelectMode;
}
