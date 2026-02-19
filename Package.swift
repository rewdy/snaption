// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "PhotoInfoApp",
    platforms: [
        .macOS(.v14),
    ],
    targets: [
        .executableTarget(
            name: "PhotoInfoApp"
        ),
        .testTarget(
            name: "PhotoInfoAppTests",
            dependencies: ["PhotoInfoApp"]
        ),
    ]
)
