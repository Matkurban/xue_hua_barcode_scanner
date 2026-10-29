#ifndef XUE_HUA_BARCODE_SCANNER_ZXING_FALLBACK_CODEC_H_
#define XUE_HUA_BARCODE_SCANNER_ZXING_FALLBACK_CODEC_H_

#include "zxing_ffi_bridge.h"

#include <algorithm>
#include <cmath>
#include <cstdint>
#include <string>
#include <vector>

namespace xh_scanner_internal {

inline void RenderFallbackBarcodeMatrix(
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

inline bool TryDecodeFallbackBarcodeMatrix(
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

}  // namespace xh_scanner_internal

#endif  // XUE_HUA_BARCODE_SCANNER_ZXING_FALLBACK_CODEC_H_
