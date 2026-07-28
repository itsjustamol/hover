// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Context",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "Context", path: "Sources/Context")
    ]
)
