#
# xue_hua_barcode_scanner.podspec (iOS)
# Author: Matkurban <3496354336@qq.com>
# Repository: https://github.com/Matkurban/xue_hua_barcode_scanner
#
Pod::Spec.new do |s|
  s.name             = 'xue_hua_barcode_scanner'
  s.version          = '0.1.0'
  s.summary          = 'Cross-platform Flutter QR Code & Barcode scanner plugin powered by zxing-cpp FFI.'
  s.description      = <<-DESC
A 6-platform Flutter QR Code and Barcode recognition, generation, and real-time camera scanner plugin powered by zxing-cpp C++20 FFI and WebAssembly.
                       DESC
  s.homepage         = 'https://github.com/Matkurban/xue_hua_barcode_scanner'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Matkurban' => '3496354336@qq.com' }

  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*.{h,m,mm,cpp,swift}'
  s.public_header_files = 'Classes/**/*.h'
  s.dependency 'Flutter'
  s.platform         = :ios, '13.0'
  s.frameworks       = 'AVFoundation', 'CoreVideo', 'CoreMedia', 'CoreImage', 'ImageIO'
  s.libraries        = 'c++'

  # Optional: If vendoring zxing-cpp under ios/zxing-cpp/core/src, compile it in a subspec
  if Dir.exist?(File.join(__dir__, 'zxing-cpp/core/src'))
    s.subspec 'ZXingCore' do |zx|
      zx.source_files = 'zxing-cpp/core/src/**/*.{h,cpp}'
      zx.header_dir   = 'ZXing'
      zx.private_header_files = 'zxing-cpp/core/src/**/*.h'
    end
  end

  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386',
    'CLANG_CXX_LANGUAGE_STANDARD' => 'c++20',
    'CLANG_CXX_LIBRARY' => 'libc++',
    'GCC_PREPROCESSOR_DEFINITIONS' => '$(inherited) DART_SHARED_LIB=1',
    # Prevent Xcode Archive/Release from stripping exported FFI C symbols
    'STRIP_STYLE' => 'non-global',
    'DEAD_CODE_STRIPPING' => 'NO',
    'OTHER_LDFLAGS' => '$(inherited) -Wl,-exported_symbol,_zxing_engine_version -Wl,-exported_symbol,_zxing_decode_image_bytes -Wl,-exported_symbol,_free_barcode_results -Wl,-exported_symbol,_zxing_encode_qr_code -Wl,-exported_symbol,_free_encoded_qr_image'
  }
  s.swift_version = '5.0'
end
