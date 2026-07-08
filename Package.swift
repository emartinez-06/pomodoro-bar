// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PomodoroBar",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "PomodoroBar",
            path: "Sources/PomodoroBar",
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
