#ifndef XUE_HUA_BARCODE_SCANNER_ZXING_IMAGE_PREPROCESS_H_
#define XUE_HUA_BARCODE_SCANNER_ZXING_IMAGE_PREPROCESS_H_

#include "zxing_ffi_bridge.h"

#include <algorithm>
#include <cstdint>
#include <cstdlib>
#include <cstring>
#include <string>
#include <vector>

#if __has_include("ZXingCpp.h")
#define XH_HAS_ZXING_CPP 1
#include "ZXingCpp.h"
#elif __has_include(<ZXing/ZXingCpp.h>)
#define XH_HAS_ZXING_CPP 1
#include <ZXing/ZXingCpp.h>
#elif __has_include("ReadBarcode.h")
#define XH_HAS_ZXING_CPP 1
#include "BarcodeFormat.h"
#include "CreateBarcode.h"
#include "ImageView.h"
#include "ReadBarcode.h"
#include "ReaderOptions.h"
#include "WriteBarcode.h"
#else
#define XH_HAS_ZXING_CPP 0
#endif

namespace xh_scanner_internal {

inline char* DuplicateCString(const std::string& str) {
  char* buffer = static_cast<char*>(std::malloc(str.size() + 1));
  if (buffer != nullptr) {
    std::memcpy(buffer, str.data(), str.size());
    buffer[str.size()] = '\0';
  }
  return buffer;
}

#if XH_HAS_ZXING_CPP
inline ZXing::ImageFormat MapPixelFormat(int32_t format, int32_t* out_bytes_per_pixel) {
  switch (format) {
    case C_PIXEL_FORMAT_LUM:
      *out_bytes_per_pixel = 1;
      return ZXing::ImageFormat::Lum;
    case C_PIXEL_FORMAT_RGBA8888:
      *out_bytes_per_pixel = 4;
      return ZXing::ImageFormat::RGBA;
    case C_PIXEL_FORMAT_BGRA8888:
      *out_bytes_per_pixel = 4;
      return ZXing::ImageFormat::BGRA;
    case C_PIXEL_FORMAT_RGB888:
      *out_bytes_per_pixel = 3;
      return ZXing::ImageFormat::RGB;
    default:
      *out_bytes_per_pixel = 4;
      return ZXing::ImageFormat::RGBA;
  }
}

inline int32_t MapBarcodeFormat(ZXing::BarcodeFormat format) {
  switch (format) {
    case ZXing::BarcodeFormat::QRCode:
    case ZXing::BarcodeFormat::QRCodeModel1:
    case ZXing::BarcodeFormat::QRCodeModel2:
      return C_BARCODE_FORMAT_QR_CODE;
    case ZXing::BarcodeFormat::MicroQRCode:
      return C_BARCODE_FORMAT_MICRO_QR_CODE;
    case ZXing::BarcodeFormat::RMQRCode:
      return C_BARCODE_FORMAT_RMQR_CODE;
    case ZXing::BarcodeFormat::DataMatrix:
      return C_BARCODE_FORMAT_DATA_MATRIX;
    case ZXing::BarcodeFormat::Aztec:
    case ZXing::BarcodeFormat::AztecCode:
    case ZXing::BarcodeFormat::AztecRune:
      return C_BARCODE_FORMAT_AZTEC;
    case ZXing::BarcodeFormat::PDF417:
      return C_BARCODE_FORMAT_PDF417;
    case ZXing::BarcodeFormat::CompactPDF417:
      return C_BARCODE_FORMAT_COMPACT_PDF417;
    case ZXing::BarcodeFormat::MicroPDF417:
      return C_BARCODE_FORMAT_MICRO_PDF417;
    case ZXing::BarcodeFormat::Code128:
      return C_BARCODE_FORMAT_CODE_128;
    case ZXing::BarcodeFormat::Code39:
    case ZXing::BarcodeFormat::Code39Std:
    case ZXing::BarcodeFormat::Code39Ext:
    case ZXing::BarcodeFormat::Code32:
    case ZXing::BarcodeFormat::PZN:
      return C_BARCODE_FORMAT_CODE_39;
    case ZXing::BarcodeFormat::Code93:
      return C_BARCODE_FORMAT_CODE_93;
    case ZXing::BarcodeFormat::EAN13:
    case ZXing::BarcodeFormat::ISBN:
      return C_BARCODE_FORMAT_EAN_13;
    case ZXing::BarcodeFormat::EAN8:
      return C_BARCODE_FORMAT_EAN_8;
    case ZXing::BarcodeFormat::UPCA:
      return C_BARCODE_FORMAT_UPC_A;
    case ZXing::BarcodeFormat::UPCE:
      return C_BARCODE_FORMAT_UPC_E;
    case ZXing::BarcodeFormat::ITF:
    case ZXing::BarcodeFormat::ITF14:
      return C_BARCODE_FORMAT_ITF;
    case ZXing::BarcodeFormat::Codabar:
      return C_BARCODE_FORMAT_CODABAR;
    case ZXing::BarcodeFormat::DataBar:
    case ZXing::BarcodeFormat::DataBarOmni:
    case ZXing::BarcodeFormat::DataBarStk:
    case ZXing::BarcodeFormat::DataBarStkOmni:
      return C_BARCODE_FORMAT_DATA_BAR;
    case ZXing::BarcodeFormat::DataBarExp:
    case ZXing::BarcodeFormat::DataBarExpStk:
      return C_BARCODE_FORMAT_DATA_BAR_EXPANDED;
    case ZXing::BarcodeFormat::DataBarLtd:
      return C_BARCODE_FORMAT_DATA_BAR_LIMITED;
    case ZXing::BarcodeFormat::MaxiCode:
      return C_BARCODE_FORMAT_MAXI_CODE;
    case ZXing::BarcodeFormat::Telepen:
    case ZXing::BarcodeFormat::TelepenAlpha:
    case ZXing::BarcodeFormat::TelepenNumeric:
      return C_BARCODE_FORMAT_TELEPEN;
    case ZXing::BarcodeFormat::DXFilmEdge:
      return C_BARCODE_FORMAT_DX_FILM_EDGE;
    default:
      return C_BARCODE_FORMAT_UNKNOWN;
  }
}

inline std::string MapEccLevelOption(int32_t ecc_level) {
#ifdef ZXING_USE_ZINT
  switch (ecc_level) {
    case C_BARCODE_ECC_LOW:
      return "ecLevel=L";
    case C_BARCODE_ECC_MEDIUM:
      return "ecLevel=M";
    case C_BARCODE_ECC_QUARTILE:
      return "ecLevel=Q";
    case C_BARCODE_ECC_HIGH:
      return "ecLevel=H";
    default:
      return "ecLevel=M";
  }
#else
  switch (ecc_level) {
    case C_BARCODE_ECC_LOW:
      return "ecLevel=1";
    case C_BARCODE_ECC_MEDIUM:
      return "ecLevel=3";
    case C_BARCODE_ECC_QUARTILE:
      return "ecLevel=5";
    case C_BARCODE_ECC_HIGH:
      return "ecLevel=7";
    default:
      return "ecLevel=3";
  }
#endif
}

inline std::vector<uint8_t> ConvertToLuminance(
    const uint8_t* pixels,
    int32_t width,
    int32_t height,
    int32_t row_stride,
    int32_t pixel_format,
    int32_t bytes_per_pixel) {
  std::vector<uint8_t> lum(static_cast<size_t>(width) * height);
  for (int32_t y = 0; y < height; ++y) {
    const uint8_t* row = pixels + static_cast<size_t>(y) * row_stride;
    uint8_t* dst = lum.data() + static_cast<size_t>(y) * width;
    if (pixel_format == C_PIXEL_FORMAT_LUM) {
      std::memcpy(dst, row, static_cast<size_t>(width));
    } else if (pixel_format == C_PIXEL_FORMAT_BGRA8888) {
      for (int32_t x = 0; x < width; ++x) {
        const uint8_t* p = row + x * bytes_per_pixel;
        dst[x] = static_cast<uint8_t>((306 * p[2] + 601 * p[1] + 117 * p[0] + 512) >> 10);
      }
    } else {
      for (int32_t x = 0; x < width; ++x) {
        const uint8_t* p = row + x * bytes_per_pixel;
        dst[x] = static_cast<uint8_t>((306 * p[0] + 601 * p[1] + 117 * p[2] + 512) >> 10);
      }
    }
  }
  return lum;
}

inline std::vector<uint8_t> DilateDarkDots3x3(
    const std::vector<uint8_t>& lum,
    int32_t width,
    int32_t height) {
  std::vector<uint8_t> temp(lum.size());
  std::vector<uint8_t> out(lum.size());
  for (int32_t y = 0; y < height; ++y) {
    const uint8_t* row = lum.data() + static_cast<size_t>(y) * width;
    uint8_t* dst = temp.data() + static_cast<size_t>(y) * width;
    for (int32_t x = 0; x < width; ++x) {
      uint8_t m = row[x];
      if (x > 0 && row[x - 1] < m) m = row[x - 1];
      if (x + 1 < width && row[x + 1] < m) m = row[x + 1];
      dst[x] = m;
    }
  }
  for (int32_t y = 0; y < height; ++y) {
    const uint8_t* r0 = temp.data() + static_cast<size_t>(std::max(0, y - 1)) * width;
    const uint8_t* r1 = temp.data() + static_cast<size_t>(y) * width;
    const uint8_t* r2 = temp.data() + static_cast<size_t>(std::min(height - 1, y + 1)) * width;
    uint8_t* dst = out.data() + static_cast<size_t>(y) * width;
    for (int32_t x = 0; x < width; ++x) {
      dst[x] = std::min({r0[x], r1[x], r2[x]});
    }
  }
  return out;
}

inline std::vector<uint8_t> DownscaleLum2x(
    const std::vector<uint8_t>& lum,
    int32_t width,
    int32_t height,
    int32_t* out_w,
    int32_t* out_h) {
  const int32_t dw = width / 2;
  const int32_t dh = height / 2;
  *out_w = dw;
  *out_h = dh;
  std::vector<uint8_t> out(static_cast<size_t>(dw) * dh);
  for (int32_t y = 0; y < dh; ++y) {
    const uint8_t* r0 = lum.data() + static_cast<size_t>(y * 2) * width;
    const uint8_t* r1 = lum.data() + static_cast<size_t>(y * 2 + 1) * width;
    uint8_t* dst = out.data() + static_cast<size_t>(y) * dw;
    for (int32_t x = 0; x < dw; ++x) {
      const int sum = r0[x * 2] + r0[x * 2 + 1] + r1[x * 2] + r1[x * 2 + 1];
      dst[x] = static_cast<uint8_t>((sum + 2) >> 2);
    }
  }
  return out;
}
#endif

}  // namespace xh_scanner_internal

#endif  // XUE_HUA_BARCODE_SCANNER_ZXING_IMAGE_PREPROCESS_H_
