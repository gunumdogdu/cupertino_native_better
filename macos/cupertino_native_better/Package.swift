// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "cupertino_native_better",
    platforms: [
        .macOS("12.0")
    ],
    products: [
        .library(name: "cupertino-native-better", targets: ["cupertino_native_better"])
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework")
    ],
    targets: [
        .target(
            name: "cupertino_native_better",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework")
            ],
            path: "Sources/cupertino_native_better",
            resources: [
                .process("PrivacyInfo.xcprivacy")
            ]
        )
    ]
)
