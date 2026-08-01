// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "HandFlow",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "HandFlow", targets: ["HandFlow"])
    ],
    targets: [
        .executableTarget(
            name: "HandFlow",
            path: "Sources/HandFlow",
            exclude: ["Resources"]
        ),
        .testTarget(
            name: "HandFlowTests",
            dependencies: ["HandFlow"],
            path: "Tests/HandFlowTests"
        )
    ]
)
