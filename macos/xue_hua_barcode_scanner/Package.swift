// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "xue_hua_barcode_scanner",
    platforms: [
        .macOS("10.15")
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
        .target(
            name: "xue_hua_barcode_scanner_ffi",
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
                .linkedFramework("AppKit")
            ]
        )
    ],
    cxxLanguageStandard: .cxx20
)
