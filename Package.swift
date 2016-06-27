import PackageDescription

let package = Package(
    name: "reminders",
    dependencies: [
        .Package(url: "https://github.com/kylef/Commander", majorVersion:0)
    ]
)
