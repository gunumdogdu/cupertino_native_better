// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "cupertino_native_better",
    platforms: [
        .iOS("15.0")
    ],
    products: [
        .library(name: "cupertino-native-better", targets: ["cupertino_native_better"])
    ],
    dependencies: [
        .package(url: "https://github.com/SVGKit/SVGKit.git", from: "3.0.0"),
        // SVGKit 3.0.0 accepts CocoaLumberjack 3.10+, which needs iOS 15 while
        // SVGKit's target declares iOS 9, so Xcode rejects the build (#80).
        // Remove once SVGKit tags a release that carries its own cap.
        .package(url: "https://github.com/CocoaLumberjack/CocoaLumberjack.git", "3.7.0"..<"3.10.0")
    ],
    targets: [
        .target(
            name: "cupertino_native_better",
            dependencies: [
                .product(name: "SVGKit", package: "SVGKit"),
                // Listed so SwiftPM applies the cap above; unused deps are ignored.
                .product(name: "CocoaLumberjack", package: "CocoaLumberjack")
            ],
            path: "Sources/cupertino_native_better",
            resources: [
                .process("PrivacyInfo.xcprivacy")
            ]
        )
    ]
)
