// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "WinMan",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "WinMan",
            targets: ["WinMan"]
        )
    ],
    targets: [
        .executableTarget(
            name: "WinMan",
            path: "Sources/WinMan"
        )
    ]
)
