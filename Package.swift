// swift-tools-version: 6.2

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
    ]
)
