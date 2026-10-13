// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "gworkbench",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .executable(
            name: "GWorkbenchApp",
            targets: ["GWorkbenchApp"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/LebJe/TOMLKit.git", from: "0.6.0"),
    ],
    targets: [
        .executableTarget(
            name: "GWorkbenchApp",
            dependencies: [
                .product(name: "TOMLKit", package: "TOMLKit"),
            ],
            path: "Sources/GWorkbenchApp"
        ),
    ]
)
