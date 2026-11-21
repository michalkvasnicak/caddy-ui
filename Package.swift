// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CaddyUI",
    platforms: [.macOS(.v14)],
    targets: [.executableTarget(name: "CaddyUI")]
)
