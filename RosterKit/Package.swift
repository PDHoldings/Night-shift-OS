// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "RosterKit",
    platforms: [
        .iOS(.v18),
        .macOS(.v14),
    ],
    products: [
        .library(name: "RosterKit", targets: ["RosterKit"]),
    ],
    targets: [
        .target(
            name: "RosterKit",
            path: "Sources/RosterKit"
        ),
        .testTarget(
            name: "RosterKitTests",
            dependencies: ["RosterKit"],
            path: "Tests/RosterKitTests"
        ),
    ]
)
