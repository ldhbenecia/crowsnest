// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Crowsnest",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Crowsnest", targets: ["CrowsnestApp"])
    ],
    targets: [
        .target(name: "CrowsnestKit", path: "Sources/CrowsnestKit"),
        .executableTarget(name: "CrowsnestApp", dependencies: ["CrowsnestKit"], path: "Sources/CrowsnestApp"),
        .testTarget(name: "CrowsnestKitTests", dependencies: ["CrowsnestKit"], path: "Tests/CrowsnestKitTests")
    ]
)
