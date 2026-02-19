// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "Snaption",
    platforms: [
        .macOS(.v14),
    ],
    targets: [
        .executableTarget(
            name: "Snaption"
        ),
        .testTarget(
            name: "SnaptionTests",
            dependencies: ["Snaption"]
        ),
    ]
)
