// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "CornerShot",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "CornerShot", targets: ["CornerShot"])
    ],
    targets: [
        .executableTarget(
            name: "CornerShot",
            path: "Sources/CornerShot"
        )
    ]
)
