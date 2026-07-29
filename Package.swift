// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Feather",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "Feather", path: "Sources/Feather")
    ]
)
