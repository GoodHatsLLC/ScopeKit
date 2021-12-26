// swift-tools-version:5.3
import PackageDescription

let package = Package(
    name: "ScopeKit",
    platforms: [
        .macOS(.v11),
        .iOS(.v13)
    ],
    products: [
        .library(
            name: "ScopeKit",
            targets: ["ScopeKit"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "ScopeKit",
            dependencies: []),
        .testTarget(
            name: "ScopeKitTests",
            dependencies: ["ScopeKit"]),
    ]
)
