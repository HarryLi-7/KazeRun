// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "KazeRun",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "KazeRun", targets: ["KazeRun"])
    ],
    targets: [
        .executableTarget(
            name: "KazeRun",
            path: "Sources/KazeRun"
        )
    ]
)
