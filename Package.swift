// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "HangulInputFixer",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "HangulInputCore", targets: ["HangulInputCore"]),
        .executable(name: "HangulInputFixer", targets: ["HangulInputApp"]),
        .executable(name: "CoreTests", targets: ["CoreTests"]),
        .executable(name: "CoreBenchmark", targets: ["CoreBenchmark"]),
    ],
    targets: [
        .target(name: "HangulInputCore"),
        .executableTarget(
            name: "HangulInputApp",
            dependencies: ["HangulInputCore"],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("Carbon"),
                .linkedFramework("CoreGraphics"),
                .linkedFramework("ApplicationServices"),
            ]
        ),
        .executableTarget(name: "CoreTests", dependencies: ["HangulInputCore"], path: "Tests/HangulInputCoreTests"),
        .executableTarget(name: "CoreBenchmark", dependencies: ["HangulInputCore"], path: "Tests/Performance"),
    ],
    swiftLanguageModes: [.v5]
)
