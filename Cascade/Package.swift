// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Cascade",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "Cascade",
            targets: ["Cascade"]
        )
    ],
    targets: [
        .executableTarget(
            name: "Cascade",
            path: "Sources",
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        .testTarget(
            name: "CascadeTests",
            dependencies: ["Cascade"],
            path: "Tests"
        )
    ]
)
