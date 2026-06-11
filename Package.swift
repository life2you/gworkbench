// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "gworkbench",
    platforms: [
        .macOS(.v15),
    ],
    products: [
        .executable(
            name: "GWorkbenchApp",
            targets: ["GWorkbenchApp"]
        ),
    ],
    targets: [
        .executableTarget(
            name: "GWorkbenchApp",
            path: "Sources/GWorkbenchApp"
        ),
    ]
)
