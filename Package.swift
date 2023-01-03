// swift-tools-version:5.5
import PackageDescription

let package = Package(
    name: "reminders",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .executable(name: "reminders", targets: ["reminders"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", .upToNextMinor(from: "1.1.4")),
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
