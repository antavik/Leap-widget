// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LeapCore",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "LeapCore", targets: ["LeapCore"])
    ],
    dependencies: [],  // G11: zero third-party dependencies
    targets: [
        .target(name: "LeapCore",
                resources: [.process("Localizable.xcstrings")]),
        .testTarget(name: "LeapCoreTests", dependencies: ["LeapCore"]),
    ]
)
