// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Ajar",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "AjarCore", targets: ["AjarCore"]),
        .executable(name: "AjarApp", targets: ["AjarApp"]),
        .executable(name: "ajar", targets: ["AjarCLI"]),
    ],
    targets: [
        .target(name: "AjarCore", path: "Sources/AjarCore"),
        .executableTarget(name: "AjarApp", dependencies: ["AjarCore"], path: "Sources/AjarApp",
                          resources: [.copy("Resources/GitHubMark.svg"),
                                      .copy("Resources/DoorClose.aiff"), .copy("Resources/DoorOpen.aiff"),
                                      .copy("Resources/DancingDog.gif")]),
        .executableTarget(name: "AjarCLI", dependencies: ["AjarCore"], path: "Sources/AjarCLI"),
        .testTarget(name: "AjarAppTests", dependencies: ["AjarApp"], path: "Tests/AjarAppTests"),
        .testTarget(name: "AjarCoreTests", dependencies: ["AjarCore"], path: "Tests/AjarCoreTests"),
    ]
)
