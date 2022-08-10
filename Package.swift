// swift-tools-version:5.3
import PackageDescription

let package = Package(
    name: "reminders",
    platforms: [
        .macOS(.v11)
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", .upToNextMinor(from: "0.3.0")),
        .package(url: "https://github.com/apple/swift-system", from: "0.0.1"),
    ],
    targets: [
        .target(
            name: "reminders",
            dependencies: ["RemindersLibrary",             .product(name: "SystemPackage", package: "swift-system"),]
        ),
        .target(
            name: "RemindersLibrary",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                            .product(name: "SystemPackage", package: "swift-system"),
            ]
        ),
        .testTarget(
            name: "RemindersTests",
            dependencies: ["RemindersLibrary",             .product(name: "SystemPackage", package: "swift-system"),]
        ),
    ]
)
