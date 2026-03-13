// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TiltAdmin",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/jpsim/Yams.git", from: "5.0.0"),
    ],
    targets: [
        .target(
            name: "TiltAdminLib",
            dependencies: ["Yams"],
            path: "Sources/TiltAdminLib"
        ),
        .executableTarget(
            name: "TiltAdmin",
            dependencies: ["TiltAdminLib"],
            path: "Sources/TiltAdmin"
        ),
        .testTarget(
            name: "TiltAdminTests",
            dependencies: ["TiltAdminLib"],
            path: "Tests/TiltAdminTests"
        ),
    ]
)
