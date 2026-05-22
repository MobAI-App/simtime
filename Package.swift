// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "simtime",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "simtime", targets: ["simtime"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.3.0"),
    ],
    targets: [
        .executableTarget(
            name: "simtime",
            dependencies: [
                "SimtimeCore",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),
        .target(
            name: "SimtimeCore"
        ),
        .testTarget(
            name: "SimtimeCoreTests",
            dependencies: ["SimtimeCore"]
        ),
    ]
)
