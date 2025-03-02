// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SquareetlabsCapacitorOpenwith",
    platforms: [.iOS(.v13)],
    products: [
        .library(
            name: "SquareetlabsCapacitorOpenwith",
            targets: ["OpenWithPlugin"])
    ],
    dependencies: [
        .package(url: "https://github.com/ionic-team/capacitor-swift-pm.git", branch: "main")
    ],
    targets: [
        .target(
            name: "OpenWithPlugin",
            dependencies: [
                .product(name: "Capacitor", package: "capacitor-swift-pm"),
                .product(name: "Cordova", package: "capacitor-swift-pm")
            ],
            path: "ios/Sources/OpenWithPlugin"),
        .testTarget(
            name: "OpenWithPluginTests",
            dependencies: ["OpenWithPlugin"],
            path: "ios/Tests/OpenWithPluginTests")
    ]
)