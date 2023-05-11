// swift-tools-version:5.7
import PackageDescription

let package = Package(
    name: "feather-storage",
    platforms: [
       .macOS(.v12),
    ],
    products: [
        .library(name: "FeatherStorage", targets: ["FeatherStorage"]),
        .library(name: "FeatherFileStorage", targets: ["FeatherFileStorage"]),
        .library(name: "FeatherS3Storage", targets: ["FeatherS3Storage"]),
        .library(name: "SotoS3", targets: ["SotoS3"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-nio", from: "2.51.0"),
        .package(url: "https://github.com/apple/swift-log", from: "1.5.0"),
        .package(url: "https://github.com/soto-project/soto-core", from: "6.5.0"),
        .package(url: "https://github.com/soto-project/soto-codegenerator", from: "0.8.0"),
    ],
    targets: [
        .target(name: "FeatherStorage", dependencies: [
            .product(name: "NIO", package: "swift-nio"),
        ]),
        .target(name: "FeatherFileStorage", dependencies: [
            .product(name: "Logging", package: "swift-log"),
            .target(name: "FeatherStorage"),
        ]),
        .target(name: "FeatherS3Storage", dependencies: [
            .target(name: "SotoS3"),
            .target(name: "FeatherStorage"),
        ]),
        .target(
            name: "SotoS3",
            dependencies: [
                .product(name: "SotoCore", package: "soto-core"),
            ],
            plugins: [
                .plugin(
                    name: "SotoCodeGeneratorPlugin",
                    package: "soto-codegenerator"
                ),
            ]
        ),
        .testTarget(name: "FeatherFileStorageTests", dependencies: [
            .target(name: "FeatherFileStorage"),
        ]),
        .testTarget(name: "FeatherS3StorageTests", dependencies: [
            .target(name: "FeatherS3Storage"),
        ]),
    ]
)
