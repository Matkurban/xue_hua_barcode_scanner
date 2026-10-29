#include "zxing_ffi_bridge.h"

#include "zxing_fallback_codec.h"
#include "zxing_image_preprocess.h"

#include <algorithm>
#include <cmath>
#include <cstdlib>
#include <cstring>
#include <exception>
#include <string>
#include <string_view>
#include <vector>

using xh_scanner_internal::DuplicateCString;
#if XH_HAS_ZXING_CPP
using xh_scanner_internal::ConvertToLuminance;
using xh_scanner_internal::DilateDarkDots3x3;
using xh_scanner_internal::DownscaleLum2x;
using xh_scanner_internal::MapBarcodeFormat;
using xh_scanner_internal::MapEccLevelOption;
using xh_scanner_internal::MapPixelFormat;
#else
using xh_scanner_internal::RenderFallbackBarcodeMatrix;
using xh_scanner_internal::TryDecodeFallbackBarcodeMatrix;
#endif

extern "C" {

XH_FFI_EXPORT const char* zxing_engine_version(void) {
#if XH_HAS_ZXING_CPP
  return "zxing-cpp 3.1.1 (C++20 FFI)";
#else
  return "zxing-cpp 3.1.1-bridge";
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

    const ZXing::ImageView image_view(
        pixels,
        width,
        height,
        zxing_format,
        effective_row_stride,
        bytes_per_pixel);

    auto base_options = ZXing::ReaderOptions()
                            .formats(ZXing::BarcodeFormat::AllReadable)
                            .tryHarder(try_harder != 0)
                            .tryRotate(try_rotate != 0)
                            .tryInvert(try_invert != 0)
                            .tryDownscale(true)
                            .binarizer(ZXing::Binarizer::LocalAverage)
                            .returnErrors(false);
#ifdef ZXING_EXPERIMENTAL_API
    base_options.setTryDenoise(true);
#endif

    double coordinate_scale = 1.0;
    ZXing::Barcodes barcodes = ZXing::ReadBarcodes(image_view, base_options);

    if (barcodes.empty() && try_harder != 0) {
      auto hist_options = base_options;
      hist_options.setBinarizer(ZXing::Binarizer::GlobalHistogram);
      barcodes = ZXing::ReadBarcodes(image_view, hist_options);
    }

    if (barcodes.empty() && try_harder != 0 && width >= 48 && height >= 48) {
      const std::vector<uint8_t> lum = ConvertToLuminance(
          pixels,
          width,
          height,
          effective_row_stride,
          pixel_format,
          bytes_per_pixel);

      const std::vector<uint8_t> dilated1 = DilateDarkDots3x3(lum, width, height);
      const ZXing::ImageView dilated1_view(
          dilated1.data(),
          width,
          height,
          ZXing::ImageFormat::Lum);
      barcodes = ZXing::ReadBarcodes(dilated1_view, base_options);

      if (barcodes.empty() && width >= 120 && height >= 120) {
        int32_t half_w = 0;
        int32_t half_h = 0;
        const std::vector<uint8_t> half_lum =
            DownscaleLum2x(lum, width, height, &half_w, &half_h);
        const std::vector<uint8_t> dilated_half =
            DilateDarkDots3x3(half_lum, half_w, half_h);
        const ZXing::ImageView dilated_half_view(
            dilated_half.data(),
            half_w,
            half_h,
            ZXing::ImageFormat::Lum);
        barcodes = ZXing::ReadBarcodes(dilated_half_view, base_options);
        if (!barcodes.empty()) {
          coordinate_scale = 2.0;
        }
      }
    }

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
      dst.corner_points[0] = {static_cast<double>(pos.topLeft().x) * coordinate_scale,
                              static_cast<double>(pos.topLeft().y) * coordinate_scale};
      dst.corner_points[1] = {static_cast<double>(pos.topRight().x) * coordinate_scale,
                              static_cast<double>(pos.topRight().y) * coordinate_scale};
      dst.corner_points[2] = {static_cast<double>(pos.bottomRight().x) * coordinate_scale,
                              static_cast<double>(pos.bottomRight().y) * coordinate_scale};
      dst.corner_points[3] = {static_cast<double>(pos.bottomLeft().x) * coordinate_scale,
                              static_cast<double>(pos.bottomLeft().y) * coordinate_scale};

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
    const ZXing::CreatorOptions creator_options(
        ZXing::BarcodeFormat::QRCode,
        MapEccLevelOption(ecc_level));
    const ZXing::Barcode barcode =
        ZXing::CreateBarcodeFromText(std::string_view(content), creator_options);
    const ZXing::ImageView symbol = barcode.symbol();
    if (symbol.data() == nullptr || symbol.width() <= 0 || symbol.height() <= 0) {
      std::free(rgba);
      result->error_message = DuplicateCString("ZXing::CreateBarcodeFromText returned an empty symbol matrix.");
      return result;
    }

    std::fill(rgba, rgba + byte_length, 255);
    const int32_t sym_w = symbol.width();
    const int32_t sym_h = symbol.height();
    const int32_t total_modules_x = sym_w + (safe_margin * 2);
    const int32_t total_modules_y = sym_h + (safe_margin * 2);
    const double module_w = static_cast<double>(safe_width) / total_modules_x;
    const double module_h = static_cast<double>(safe_height) / total_modules_y;

    for (int32_t my = 0; my < sym_h; ++my) {
      for (int32_t mx = 0; mx < sym_w; ++mx) {
        const bool is_black = (*symbol.data(mx, my) != 0);
        if (!is_black) {
          continue;
        }
        const int32_t x0 = static_cast<int32_t>(std::floor((mx + safe_margin) * module_w));
        const int32_t y0 = static_cast<int32_t>(std::floor((my + safe_margin) * module_h));
        const int32_t x1 = std::min<int32_t>(
            safe_width,
            static_cast<int32_t>(std::ceil((mx + safe_margin + 1) * module_w)));
        const int32_t y1 = std::min<int32_t>(
            safe_height,
            static_cast<int32_t>(std::ceil((my + safe_margin + 1) * module_h)));
        for (int32_t py = y0; py < y1; ++py) {
          for (int32_t px = x0; px < x1; ++px) {
            const int32_t offset = (py * safe_width + px) * 4;
            rgba[offset + 0] = 0;
            rgba[offset + 1] = 0;
            rgba[offset + 2] = 0;
            rgba[offset + 3] = 255;
          }
        }
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
        DuplicateCString("Unknown C++ exception during ZXing::CreateBarcodeFromText.");
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
