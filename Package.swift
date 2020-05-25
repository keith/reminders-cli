// swift-tools-version:5.1

import PackageDescription

let package = Package(
    name: "reminders",
    dependencies: [
        .package(url: "https://github.com/kylef/Commander", from: "0.9.1"),
    ],
    targets: [
        .target(
            name: "reminders",
            dependencies: ["Commander"],
            path: "Sources"),
    ]
)
