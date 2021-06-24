// swift-tools-version:5.3
import PackageDescription

let package = Package(
    name: "reminders",
    platforms: [
        .macOS(.v11)
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", .upToNextMinor(from: "0.3.0")),
    ],
    targets: [
        .target(
            name: "reminders",
            dependencies: ["RemindersLibrary"]
        ),
        .target(
            name: "RemindersLibrary",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),
        .testTarget(
            name: "RemindersTests",
            dependencies: ["RemindersLibrary"]
        ),
    ]
)
