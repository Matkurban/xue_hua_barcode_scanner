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
        .package(name: "FlutterFramework", path: "../FlutterFramework")
    ],
    targets: [
        .binaryTarget(
            name: "ZXingCpp",
            path: "Frameworks/ZXingCpp.xcframework"
        ),
        .target(
            name: "xue_hua_barcode_scanner_ffi",
            dependencies: [
                "ZXingCpp"
            ],
            path: "Sources/xue_hua_barcode_scanner_ffi",
            cSettings: [
                .headerSearchPath("include/xue_hua_barcode_scanner_ffi"),
                .define("DART_SHARED_LIB", to: "1")
            ],
            cxxSettings: [
                .headerSearchPath("include/xue_hua_barcode_scanner_ffi"),
                .headerSearchPath("../../Frameworks/ZXingCpp.xcframework/ios-arm64/Headers"),
                .headerSearchPath("../../Frameworks/ZXingCpp.xcframework/ios-arm64_x86_64-simulator/Headers"),
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
