// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "Nagbell",
    platforms: [.macOS(.v15)],
    targets: [
        .target(name: "NagbellCore"),
        .executableTarget(name: "Nagbell", dependencies: ["NagbellCore"]),
        .testTarget(name: "NagbellCoreTests", dependencies: ["NagbellCore"]),
    ]
)
