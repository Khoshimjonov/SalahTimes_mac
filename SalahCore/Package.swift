// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "SalahCore",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "SalahCore", targets: ["SalahCore"])
    ],
    targets: [
        .target(
            name: "SalahCore",
            path: "Sources/SalahCore"
        ),
        .testTarget(
            name: "SalahCoreTests",
            dependencies: ["SalahCore"],
            path: "Tests/SalahCoreTests",
            resources: [
                .copy("Fixtures")
            ]
        )
    ]
)
