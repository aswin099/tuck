// swift-tools-version:5.10
import PackageDescription

// TuckCore holds all logic that does not need AppKit (models, history store,
// search, ignore rules) so it can be unit-tested anywhere with `swift test`.
// The macOS app lives in App/ and is generated into an Xcode project by
// XcodeGen (see project.yml and README.md).
let package = Package(
    name: "TuckCore",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "TuckCore", targets: ["TuckCore"]),
    ],
    targets: [
        .target(name: "TuckCore", path: "Sources/TuckCore"),
        .testTarget(name: "TuckCoreTests", dependencies: ["TuckCore"], path: "Tests/TuckCoreTests"),
    ]
)
