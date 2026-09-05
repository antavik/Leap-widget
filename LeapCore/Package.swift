// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LeapCore",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "LeapCore", targets: ["LeapCore"])
    ],
    dependencies: [],  // G11: zero third-party dependencies
    targets: [
        .target(name: "LeapCore"),
        .testTarget(name: "LeapCoreTests", dependencies: ["LeapCore"]),
    ]
)
