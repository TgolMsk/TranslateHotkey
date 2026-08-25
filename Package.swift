// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "TranslateHotkey",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "TranslateHotkey",
            path: "Sources/TranslateHotkey"
        )
    ]
)
