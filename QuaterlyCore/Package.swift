// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "QuaterlyCore",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "QuaterlyCore", targets: ["QuaterlyCore"])
    ],
    dependencies: [],  // G11: must stay empty — CI fails the build otherwise
    targets: [
        .target(name: "QuaterlyCore"),
        .testTarget(name: "QuaterlyCoreTests", dependencies: ["QuaterlyCore"]),
    ]
)
