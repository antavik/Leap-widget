// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LeapCore",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "LeapCore", targets: ["LeapCore"])
    ],
    dependencies: [],  // G11: must stay empty — CI fails the build otherwise
    targets: [
        .target(name: "LeapCore"),
        .testTarget(name: "LeapCoreTests", dependencies: ["LeapCore"]),
    ]
)
