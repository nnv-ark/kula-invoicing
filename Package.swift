// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "KULA",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "KULA", targets: ["KULA"])
    ],
    targets: [
        // KULAApp.swift carries the @main entry point used only by the Xcode app
        // target; excluding it here keeps the SwiftPM library linkable into tests.
        .target(name: "KULA", exclude: ["KULAApp.swift"]),
        .testTarget(name: "KULATests", dependencies: ["KULA"])
    ]
)
