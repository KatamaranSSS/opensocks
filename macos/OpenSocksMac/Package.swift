// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "OpenSocksMac",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "OpenSocksMacCore",
            targets: ["OpenSocksMacCore"]
        ),
        .executable(
            name: "OpenSocksMacApp",
            targets: ["OpenSocksMacApp"]
        ),
    ],
    targets: [
        .target(
            name: "OpenSocksMacCore",
            path: "Sources/OpenSocksMacCore"
        ),
        .executableTarget(
            name: "OpenSocksMacApp",
            dependencies: ["OpenSocksMacCore"],
            path: "Sources/OpenSocksMacApp"
        ),
        .testTarget(
            name: "OpenSocksMacCoreTests",
            dependencies: ["OpenSocksMacCore"],
            path: "Tests/OpenSocksMacCoreTests"
        ),
    ]
)
