// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "xue_hua_barcode_scanner",
    platforms: [
        .iOS("13.0")
    ],
    products: [
        .library(
            name: "xue-hua-barcode-scanner",
            targets: ["xue_hua_barcode_scanner", "xue_hua_barcode_scanner_ffi"]
        )
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework"),
        .package(url: "https://github.com/zxing-cpp/zxing-cpp.git", exact: "3.1.1")
    ],
    targets: [
        .target(
            name: "xue_hua_barcode_scanner_ffi",
            dependencies: [
                .product(name: "ZXingCpp", package: "zxing-cpp")
            ],
            path: "Sources/xue_hua_barcode_scanner_ffi",
            cSettings: [
                .headerSearchPath("include/xue_hua_barcode_scanner_ffi"),
                .define("DART_SHARED_LIB", to: "1")
            ],
            cxxSettings: [
                .headerSearchPath("include/xue_hua_barcode_scanner_ffi"),
                .define("DART_SHARED_LIB", to: "1")
            ],
            linkerSettings: [
                .linkedLibrary("c++")
            ]
        ),
        .target(
            name: "xue_hua_barcode_scanner",
            dependencies: [
                "xue_hua_barcode_scanner_ffi",
                .product(name: "ZXingCpp", package: "zxing-cpp"),
                .product(name: "FlutterFramework", package: "FlutterFramework")
            ],
            path: "Sources/xue_hua_barcode_scanner",
            resources: [
                .process("PrivacyInfo.xcprivacy")
            ],
            linkerSettings: [
                .linkedFramework("AVFoundation"),
                .linkedFramework("CoreVideo"),
                .linkedFramework("CoreMedia"),
                .linkedFramework("CoreImage"),
                .linkedFramework("ImageIO"),
                .linkedFramework("PhotosUI")
            ]
        )
    ],
    cxxLanguageStandard: .cxx20
)
