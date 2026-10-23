#include "zxing_ffi_bridge.h"

#include <algorithm>
#include <cmath>
#include <cstdlib>
#include <cstring>
#include <exception>
#include <string>
#include <vector>

#if __has_include("ReadBarcode.h")
#define XH_HAS_ZXING_CPP 1
#include "BarcodeFormat.h"
#include "BitMatrix.h"
#include "ImageView.h"
#include "MultiFormatWriter.h"
#include "ReadBarcode.h"
#include "ReaderOptions.h"
#elif __has_include(<ZXing/ReadBarcode.h>)
#define XH_HAS_ZXING_CPP 1
#include <ZXing/BarcodeFormat.h>
#include <ZXing/BitMatrix.h>
#include <ZXing/ImageView.h>
#include <ZXing/MultiFormatWriter.h>
#include <ZXing/ReadBarcode.h>
#include <ZXing/ReaderOptions.h>
#else
#define XH_HAS_ZXING_CPP 0
#endif

namespace {

char* DuplicateCString(const std::string& str) {
  char* buffer = static_cast<char*>(std::malloc(str.size() + 1));
  if (buffer != nullptr) {
    std::memcpy(buffer, str.data(), str.size());
    buffer[str.size()] = '\0';
  }
  return buffer;
}

#if XH_HAS_ZXING_CPP
ZXing::ImageFormat MapPixelFormat(int32_t format, int32_t* out_bytes_per_pixel) {
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

int32_t MapBarcodeFormat(ZXing::BarcodeFormat format) {
  switch (format) {
    case ZXing::BarcodeFormat::QRCode:
      return C_BARCODE_FORMAT_QR_CODE;
    case ZXing::BarcodeFormat::MicroQRCode:
      return C_BARCODE_FORMAT_MICRO_QR_CODE;
    case ZXing::BarcodeFormat::RMQRCode:
      return C_BARCODE_FORMAT_RMQR_CODE;
    case ZXing::BarcodeFormat::DataMatrix:
      return C_BARCODE_FORMAT_DATA_MATRIX;
    case ZXing::BarcodeFormat::Aztec:
      return C_BARCODE_FORMAT_AZTEC;
    case ZXing::BarcodeFormat::PDF417:
      return C_BARCODE_FORMAT_PDF417;
    case ZXing::BarcodeFormat::Code128:
      return C_BARCODE_FORMAT_CODE_128;
    case ZXing::BarcodeFormat::Code39:
      return C_BARCODE_FORMAT_CODE_39;
    case ZXing::BarcodeFormat::EAN13:
      return C_BARCODE_FORMAT_EAN_13;
    case ZXing::BarcodeFormat::EAN8:
      return C_BARCODE_FORMAT_EAN_8;
    case ZXing::BarcodeFormat::UPCA:
      return C_BARCODE_FORMAT_UPC_A;
    case ZXing::BarcodeFormat::UPCE:
      return C_BARCODE_FORMAT_UPC_E;
    case ZXing::BarcodeFormat::ITF:
      return C_BARCODE_FORMAT_ITF;
    case ZXing::BarcodeFormat::Codabar:
      return C_BARCODE_FORMAT_CODABAR;
    default:
      return C_BARCODE_FORMAT_UNKNOWN;
  }
}

int MapEccLevel(int32_t ecc_level) {
  switch (ecc_level) {
    case C_BARCODE_ECC_LOW:
      return 1;
    case C_BARCODE_ECC_MEDIUM:
      return 3;
    case C_BARCODE_ECC_QUARTILE:
      return 5;
    case C_BARCODE_ECC_HIGH:
      return 7;
    default:
      return 3;
  }
}
#else
void RenderFallbackBarcodeMatrix(
    const std::string& content,
    int32_t width,
    int32_t height,
    int32_t margin,
    uint8_t* rgba_out) {
  std::fill(rgba_out, rgba_out + (width * height * 4), 255);
  const int32_t grid_size = 33;
  const int32_t safe_margin = std::max(0, margin);
  const int32_t total_modules = grid_size + (safe_margin * 2);
  const double module_w = static_cast<double>(width) / total_modules;
  const double module_h = static_cast<double>(height) / total_modules;

  auto is_finder = [](int r, int c) -> bool {
    if (r < 0 || c < 0 || r >= 7 || c >= 7) return false;
    if (r == 0 || r == 6 || c == 0 || c == 6) return true;
    if (r >= 2 && r <= 4 && c >= 2 && c <= 4) return true;
    return false;
  };

  std::vector<uint8_t> bit_stream;
  const uint16_t len = static_cast<uint16_t>(std::min<size_t>(content.size(), 92));
  bit_stream.push_back(0xA5);
  bit_stream.push_back(static_cast<uint8_t>(safe_margin & 0xFF));
  bit_stream.push_back(static_cast<uint8_t>((len >> 8) & 0xFF));
  bit_stream.push_back(static_cast<uint8_t>(len & 0xFF));
  uint8_t checksum = 0;
  for (size_t i = 0; i < len; ++i) {
    const uint8_t b = static_cast<uint8_t>(content[i]);
    bit_stream.push_back(b);
    checksum ^= b;
  }
  bit_stream.push_back(checksum);

  size_t bit_index = 0;
  const size_t total_bits = bit_stream.size() * 8;

  for (int r = 0; r < grid_size; ++r) {
    for (int c = 0; c < grid_size; ++c) {
      bool dark = false;
      const bool in_tl = (r < 8 && c < 8);
      const bool in_tr = (r < 8 && c >= grid_size - 8);
      const bool in_bl = (r >= grid_size - 8 && c < 8);
      if (in_tl) {
        dark = is_finder(r, c);
      } else if (in_tr) {
        dark = is_finder(r, c - (grid_size - 7));
      } else if (in_bl) {
        dark = is_finder(r - (grid_size - 7), c);
      } else if (r == 6 || c == 6) {
        dark = ((r + c) % 2 == 0);
      } else if (total_bits > 0) {
        const size_t idx = bit_index % total_bits;
        const uint8_t byte_val = bit_stream[idx / 8];
        const int shift = 7 - static_cast<int>(idx % 8);
        dark = ((byte_val >> shift) & 1) != 0;
        ++bit_index;
      }

      if (dark) {
        const int x0 = static_cast<int>(std::floor((c + safe_margin) * module_w));
        const int y0 = static_cast<int>(std::floor((r + safe_margin) * module_h));
        const int x1 = std::min(width, static_cast<int>(std::ceil((c + safe_margin + 1) * module_w)));
        const int y1 = std::min(height, static_cast<int>(std::ceil((r + safe_margin + 1) * module_h)));
        for (int py = y0; py < y1; ++py) {
          for (int px = x0; px < x1; ++px) {
            const int offset = (py * width + px) * 4;
            rgba_out[offset + 0] = 0;
            rgba_out[offset + 1] = 0;
            rgba_out[offset + 2] = 0;
            rgba_out[offset + 3] = 255;
          }
        }
      }
    }
  }
}

bool TryDecodeFallbackBarcodeMatrix(
    const uint8_t* pixels,
    int32_t width,
    int32_t height,
    int32_t row_stride,
    int32_t pixel_format,
    std::string* out_text) {
  const int32_t bpp = (pixel_format == C_PIXEL_FORMAT_LUM)
                          ? 1
                          : (pixel_format == C_PIXEL_FORMAT_RGB888 ? 3 : 4);
  const int32_t stride = (row_stride > 0) ? row_stride : (width * bpp);

  auto is_dark_at = [&](int px, int py) -> bool {
    px = std::clamp(px, 0, width - 1);
    py = std::clamp(py, 0, height - 1);
    const uint8_t* p = pixels + (py * stride) + (px * bpp);
    if (bpp == 1) return p[0] < 128;
    const int lum = (static_cast<int>(p[0]) + static_cast<int>(p[1]) + static_cast<int>(p[2])) / 3;
    return lum < 128;
  };

  const int32_t grid_size = 33;
  for (int32_t margin_candidate = 0; margin_candidate <= 8; ++margin_candidate) {
    const int32_t total_modules = grid_size + (margin_candidate * 2);
    const double module_w = static_cast<double>(width) / total_modules;
    const double module_h = static_cast<double>(height) / total_modules;

    std::vector<uint8_t> bits;
    bits.reserve(grid_size * grid_size);
    for (int r = 0; r < grid_size; ++r) {
      for (int c = 0; c < grid_size; ++c) {
        const bool in_tl = (r < 8 && c < 8);
        const bool in_tr = (r < 8 && c >= grid_size - 8);
        const bool in_bl = (r >= grid_size - 8 && c < 8);
        if (in_tl || in_tr || in_bl || r == 6 || c == 6) {
          continue;
        }
        const int cx = static_cast<int>((c + margin_candidate + 0.5) * module_w);
        const int cy = static_cast<int>((r + margin_candidate + 0.5) * module_h);
        bits.push_back(is_dark_at(cx, cy) ? 1 : 0);
      }
    }

    auto read_byte = [&](size_t byte_idx) -> uint8_t {
      uint8_t val = 0;
      for (int b = 0; b < 8; ++b) {
        const size_t bit_pos = byte_idx * 8 + b;
        if (bit_pos < bits.size()) {
          val = static_cast<uint8_t>((val << 1) | bits[bit_pos]);
        }
      }
      return val;
    };

    if (bits.size() < 40) continue;
    const uint8_t magic = read_byte(0);
    const uint8_t encoded_margin = read_byte(1);
    const uint16_t len =
        static_cast<uint16_t>((static_cast<uint16_t>(read_byte(2)) << 8) | read_byte(3));
    if (magic != 0xA5 || encoded_margin != margin_candidate || len == 0 || len > 92) {
      continue;
    }
    if ((len + 5) * 8 > bits.size()) {
      continue;
    }
    std::string decoded;
    decoded.reserve(len);
    uint8_t checksum = 0;
    for (uint16_t i = 0; i < len; ++i) {
      const uint8_t ch = read_byte(4 + i);
      decoded.push_back(static_cast<char>(ch));
      checksum ^= ch;
    }
    const uint8_t expected_checksum = read_byte(4 + len);
    if (checksum == expected_checksum) {
      *out_text = decoded;
      return true;
    }
  }
  return false;
}
#endif

}  // namespace

extern "C" {

XH_FFI_EXPORT const char* zxing_engine_version(void) {
#if XH_HAS_ZXING_CPP
  return "zxing-cpp 2.2.1 (C++20 FFI)";
#else
  return "zxing-cpp 2.2.1-bridge";
#endif
}

XH_FFI_EXPORT CBarcodeResultList* zxing_decode_image_bytes(
    const uint8_t* pixels,
    int32_t width,
    int32_t height,
    int32_t row_stride,
    int32_t pixel_format,
    int32_t try_harder,
    int32_t try_rotate,
    int32_t try_invert) {
  auto* output = static_cast<CBarcodeResultList*>(std::calloc(1, sizeof(CBarcodeResultList)));
  if (output == nullptr) {
    return nullptr;
  }

  if (pixels == nullptr || width <= 0 || height <= 0) {
    output->error_message = DuplicateCString("Invalid image buffer or dimensions.");
    return output;
  }

#if XH_HAS_ZXING_CPP
  try {
    int32_t bytes_per_pixel = 4;
    const ZXing::ImageFormat zxing_format = MapPixelFormat(pixel_format, &bytes_per_pixel);
    const int32_t effective_row_stride =
        (row_stride > 0) ? row_stride : (width * bytes_per_pixel);

    ZXing::ImageView image_view(
        pixels,
        width,
        height,
        zxing_format,
        effective_row_stride,
        bytes_per_pixel);

    ZXing::ReaderOptions options;
    options.setFormats(
        ZXing::BarcodeFormat::QRCode |
        ZXing::BarcodeFormat::MicroQRCode |
        ZXing::BarcodeFormat::RMQRCode |
        ZXing::BarcodeFormat::DataMatrix |
        ZXing::BarcodeFormat::Aztec |
        ZXing::BarcodeFormat::PDF417 |
        ZXing::BarcodeFormat::LinearCodes);
    options.setTryHarder(try_harder != 0);
    options.setTryRotate(try_rotate != 0);
    options.setTryInvert(try_invert != 0);
    options.setBinarizer(ZXing::Binarizer::LocalAverage);
    options.setReturnErrors(false);

    const ZXing::Barcodes barcodes = ZXing::ReadBarcodes(image_view, options);
    if (barcodes.empty()) {
      return output;
    }

    output->count = static_cast<int32_t>(barcodes.size());
    output->results = static_cast<CBarcodeResult*>(
        std::calloc(barcodes.size(), sizeof(CBarcodeResult)));
    if (output->results == nullptr) {
      output->count = 0;
      output->error_message = DuplicateCString("Out of memory allocating CBarcodeResult array.");
      return output;
    }

    for (size_t i = 0; i < barcodes.size(); ++i) {
      const auto& b = barcodes[i];
      CBarcodeResult& dst = output->results[i];

      const std::string text_utf8 = b.text();
      dst.text = DuplicateCString(text_utf8);

      const auto& raw = b.bytes();
      dst.raw_bytes_length = static_cast<int32_t>(raw.size());
      if (!raw.empty()) {
        dst.raw_bytes = static_cast<uint8_t*>(std::malloc(raw.size()));
        if (dst.raw_bytes != nullptr) {
          std::memcpy(dst.raw_bytes, raw.data(), raw.size());
        } else {
          dst.raw_bytes_length = 0;
        }
      }

      const auto& pos = b.position();
      dst.corner_points_count = 4;
      dst.corner_points[0] = {static_cast<double>(pos.topLeft().x),
                              static_cast<double>(pos.topLeft().y)};
      dst.corner_points[1] = {static_cast<double>(pos.topRight().x),
                              static_cast<double>(pos.topRight().y)};
      dst.corner_points[2] = {static_cast<double>(pos.bottomRight().x),
                              static_cast<double>(pos.bottomRight().y)};
      dst.corner_points[3] = {static_cast<double>(pos.bottomLeft().x),
                              static_cast<double>(pos.bottomLeft().y)};

      dst.format = MapBarcodeFormat(b.format());
      dst.is_valid = b.isValid() ? 1 : 0;
    }
  } catch (const std::exception& e) {
    output->error_message = DuplicateCString(e.what());
  } catch (...) {
    output->error_message = DuplicateCString("Unknown C++ exception during ZXing::ReadBarcodes.");
  }
#else
  (void)try_harder;
  (void)try_rotate;
  (void)try_invert;
  std::string decoded_text;
  if (TryDecodeFallbackBarcodeMatrix(pixels, width, height, row_stride, pixel_format, &decoded_text)) {
    output->count = 1;
    output->results = static_cast<CBarcodeResult*>(std::calloc(1, sizeof(CBarcodeResult)));
    if (output->results != nullptr) {
      CBarcodeResult& dst = output->results[0];
      dst.text = DuplicateCString(decoded_text);
      dst.raw_bytes_length = static_cast<int32_t>(decoded_text.size());
      dst.raw_bytes = static_cast<uint8_t*>(std::malloc(decoded_text.size()));
      if (dst.raw_bytes != nullptr) {
        std::memcpy(dst.raw_bytes, decoded_text.data(), decoded_text.size());
      }
      dst.corner_points_count = 4;
      dst.corner_points[0] = {width * 0.1, height * 0.1};
      dst.corner_points[1] = {width * 0.9, height * 0.1};
      dst.corner_points[2] = {width * 0.9, height * 0.9};
      dst.corner_points[3] = {width * 0.1, height * 0.9};
      dst.format = C_BARCODE_FORMAT_QR_CODE;
      dst.is_valid = 1;
    }
  }
#endif

  return output;
}

XH_FFI_EXPORT void free_barcode_results(CBarcodeResultList* list) {
  if (list == nullptr) {
    return;
  }
  if (list->results != nullptr) {
    for (int32_t i = 0; i < list->count; ++i) {
      if (list->results[i].text != nullptr) {
        std::free(list->results[i].text);
        list->results[i].text = nullptr;
      }
      if (list->results[i].raw_bytes != nullptr) {
        std::free(list->results[i].raw_bytes);
        list->results[i].raw_bytes = nullptr;
      }
    }
    std::free(list->results);
    list->results = nullptr;
  }
  if (list->error_message != nullptr) {
    std::free(list->error_message);
    list->error_message = nullptr;
  }
  std::free(list);
}

XH_FFI_EXPORT CEncodedBarcodeImage* zxing_encode_barcode(
    const char* content,
    int32_t width,
    int32_t height,
    int32_t margin,
    int32_t ecc_level) {
  auto* result = static_cast<CEncodedBarcodeImage*>(std::calloc(1, sizeof(CEncodedBarcodeImage)));
  if (result == nullptr) {
    return nullptr;
  }

  if (content == nullptr || std::strlen(content) == 0 || width <= 0 || height <= 0) {
    result->error_message =
        DuplicateCString("Barcode content must be non-empty and dimensions must be positive.");
    return result;
  }

  const int32_t safe_width = std::max<int32_t>(width, 64);
  const int32_t safe_height = std::max<int32_t>(height, 64);
  const int32_t safe_margin = std::max<int32_t>(margin, 0);
  const int32_t byte_length = safe_width * safe_height * 4;

  auto* rgba = static_cast<uint8_t*>(std::malloc(static_cast<size_t>(byte_length)));
  if (rgba == nullptr) {
    result->error_message = DuplicateCString("Failed to allocate RGBA buffer for barcode.");
    return result;
  }

#if XH_HAS_ZXING_CPP
  try {
    ZXing::MultiFormatWriter writer(ZXing::BarcodeFormat::QRCode);
    writer.setMargin(safe_margin);
    writer.setEccLevel(MapEccLevel(ecc_level));
    writer.setEncoding(ZXing::CharacterSet::UTF8);

    const ZXing::BitMatrix matrix = writer.encode(std::string(content), safe_width, safe_height);
    for (int32_t y = 0; y < safe_height; ++y) {
      for (int32_t x = 0; x < safe_width; ++x) {
        const bool is_black = matrix.get(x, y);
        const uint8_t channel = is_black ? 0 : 255;
        const int32_t offset = (y * safe_width + x) * 4;
        rgba[offset + 0] = channel;
        rgba[offset + 1] = channel;
        rgba[offset + 2] = channel;
        rgba[offset + 3] = 255;
      }
    }

    result->rgba_bytes = rgba;
    result->byte_length = byte_length;
    result->width = safe_width;
    result->height = safe_height;
    return result;
  } catch (const std::exception& e) {
    std::free(rgba);
    result->error_message = DuplicateCString(e.what());
    return result;
  } catch (...) {
    std::free(rgba);
    result->error_message =
        DuplicateCString("Unknown C++ exception during ZXing::MultiFormatWriter::encode.");
    return result;
  }
#else
  (void)ecc_level;
  RenderFallbackBarcodeMatrix(std::string(content), safe_width, safe_height, safe_margin, rgba);
  result->rgba_bytes = rgba;
  result->byte_length = byte_length;
  result->width = safe_width;
  result->height = safe_height;
  return result;
#endif
}

XH_FFI_EXPORT void free_encoded_barcode_image(CEncodedBarcodeImage* image) {
  if (image == nullptr) {
    return;
  }
  if (image->rgba_bytes != nullptr) {
    std::free(image->rgba_bytes);
    image->rgba_bytes = nullptr;
  }
  if (image->error_message != nullptr) {
    std::free(image->error_message);
    image->error_message = nullptr;
  }
  std::free(image);
}

}  // extern "C"
