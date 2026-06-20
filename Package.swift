// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "RUKK",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "RUKK", targets: ["RUKK"])
    ],
    targets: [
        // RUKKApp.swift carries the @main entry point used only by the Xcode app
        // target; excluding it here keeps the SwiftPM library linkable into tests.
        .target(name: "RUKK", exclude: ["RUKKApp.swift"]),
        .testTarget(name: "RUKKTests", dependencies: ["RUKK"])
    ]
)
