// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ChemCore",
    platforms: [
        .macOS(.v13), .iOS(.v16),
    ],
    products: [
        .library(name: "ChemCore", targets: ["ChemCore"]),
    ],
    targets: [
        .target(
            name: "ChemCore",
            resources: [
                .process("Resources"),
            ]
        ),
        .testTarget(
            name: "ChemCoreTests",
            dependencies: ["ChemCore"],
            resources: [
                .process("Fixtures"),
            ]
        ),
    ]
)
