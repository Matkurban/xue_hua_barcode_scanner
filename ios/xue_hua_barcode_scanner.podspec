#
# xue_hua_barcode_scanner.podspec (iOS)
# Author: Matkurban <3496354336@qq.com>
# Repository: https://github.com/Matkurban/xue_hua_barcode_scanner
#
Pod::Spec.new do |s|
  s.name             = 'xue_hua_barcode_scanner'
  s.version          = '1.0.0'
  s.summary          = 'Cross-platform Flutter Barcode & QR Code scanner plugin powered by zxing-cpp FFI.'
  s.description      = <<-DESC
A 6-platform Flutter Barcode and QR Code recognition, generation, and real-time camera scanner plugin powered by zxing-cpp C++20 FFI and WebAssembly.
                       DESC
  s.homepage         = 'https://github.com/Matkurban/xue_hua_barcode_scanner'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Matkurban' => '3496354336@qq.com' }

  s.source           = { :path => '.' }
  s.source_files     = 'xue_hua_barcode_scanner/Sources/**/*.{h,m,mm,cpp,swift}'
  s.public_header_files = 'xue_hua_barcode_scanner/Sources/xue_hua_barcode_scanner_ffi/include/**/*.h'
  s.vendored_frameworks = 'xue_hua_barcode_scanner/Frameworks/ZXingCpp.xcframework'
  s.resource_bundles = {
    'xue_hua_barcode_scanner_privacy' => [
      'xue_hua_barcode_scanner/Sources/xue_hua_barcode_scanner/PrivacyInfo.xcprivacy'
    ]
  }
  s.dependency 'Flutter'
  s.platform         = :ios, '13.0'
  s.frameworks       = 'AVFoundation', 'CoreVideo', 'CoreMedia', 'CoreImage', 'ImageIO', 'PhotosUI'
  s.libraries        = 'c++'

  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386',
    'CLANG_CXX_LANGUAGE_STANDARD' => 'c++20',
    'CLANG_CXX_LIBRARY' => 'libc++',
    'GCC_PREPROCESSOR_DEFINITIONS' => '$(inherited) DART_SHARED_LIB=1',
    'HEADER_SEARCH_PATHS' => '$(inherited) "$(PODS_TARGET_SRCROOT)/xue_hua_barcode_scanner/Frameworks/ZXingCpp.xcframework/ios-arm64/Headers" "$(PODS_TARGET_SRCROOT)/xue_hua_barcode_scanner/Frameworks/ZXingCpp.xcframework/ios-arm64_x86_64-simulator/Headers"',
    'STRIP_STYLE' => 'non-global',
    'DEAD_CODE_STRIPPING' => 'NO',
    'OTHER_LDFLAGS' => '$(inherited) -Wl,-exported_symbol,_zxing_engine_version -Wl,-exported_symbol,_zxing_decode_image_bytes -Wl,-exported_symbol,_free_barcode_results -Wl,-exported_symbol,_zxing_encode_barcode -Wl,-exported_symbol,_free_encoded_barcode_image'
  }
  s.swift_version = '5.0'
end
