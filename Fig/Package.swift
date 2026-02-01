// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Fig",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "Fig",
            targets: ["Fig"]
        )
    ],
    targets: [
        .executableTarget(
            name: "Fig",
            path: "Sources",
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        .testTarget(
            name: "FigTests",
            dependencies: ["Fig"],
            path: "Tests"
        )
    ]
)
