// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Fig",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .executable(
            name: "Fig",
            targets: ["Fig"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/SimplyDanny/SwiftLintPlugins", from: "0.58.0"),
        .package(url: "https://github.com/nicklockwood/SwiftFormat", from: "0.55.0"),
    ],
    targets: [
        .executableTarget(
            name: "Fig",
            path: "Sources",
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency"),
            ],
            plugins: [
                .plugin(name: "SwiftLintBuildToolPlugin", package: "SwiftLintPlugins"),
            ]
        ),
        .testTarget(
            name: "FigTests",
            dependencies: ["Fig"],
            path: "Tests",
            plugins: [
                .plugin(name: "SwiftLintBuildToolPlugin", package: "SwiftLintPlugins"),
            ]
        ),
    ]
)
