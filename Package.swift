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
        // 앱 아이콘을 그리는 개발용 도구 — script/make_icon.sh 에서만 씀
        .executableTarget(name: "IconRenderer", dependencies: ["CrowsnestKit"], path: "Sources/IconRenderer"),
        .testTarget(name: "CrowsnestKitTests", dependencies: ["CrowsnestKit"], path: "Tests/CrowsnestKitTests")
    ]
)
