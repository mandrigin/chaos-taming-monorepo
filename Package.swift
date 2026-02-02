// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "InputForge",
    platforms: [
        .macOS(.v26)
    ],
    targets: [
        .executableTarget(
            name: "InputForge",
            path: "Sources/InputForge"
        )
    ]
)
