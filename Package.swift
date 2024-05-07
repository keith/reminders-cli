// swift-tools-version:5.5
import PackageDescription

let package = Package(
    name: "reminders",
    platforms: [
        .macOS(.v10_15)
    ],
    products: [
        .executable(name: "reminders", targets: ["reminders"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", .upToNextMinor(from: "1.3.1")),
    ],
    targets: [
        .executableTarget(
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
