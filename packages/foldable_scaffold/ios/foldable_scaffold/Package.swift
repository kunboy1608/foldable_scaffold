// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

// The code reads the iPhone Duo data with APIs of the iOS 27.1 SDK, so building
// this package needs an Xcode that has it. See the README of the package.

let package = Package(
    name: "foldable_scaffold",
    platforms: [
        .iOS("15.0")
    ],
    products: [
        .library(name: "foldable-scaffold", targets: ["foldable_scaffold"])
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework")
    ],
    targets: [
        .target(
            name: "foldable_scaffold",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework")
            ]
        )
    ]
)
