// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "VoiceTypeMini",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "VoiceTypeMini",
            targets: ["VoiceTypeMini"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/argmaxinc/argmax-oss-swift.git", from: "0.17.0"),
        .package(url: "https://github.com/sparkle-project/Sparkle.git", from: "2.7.0")
    ],
    targets: [
        .executableTarget(
            name: "VoiceTypeMini",
            dependencies: [
                .product(name: "WhisperKit", package: "argmax-oss-swift"),
                .product(name: "Sparkle", package: "Sparkle")
            ]
        ),
        .testTarget(
            name: "VoiceTypeMiniTests",
            dependencies: ["VoiceTypeMini"]
        )
    ]
)
