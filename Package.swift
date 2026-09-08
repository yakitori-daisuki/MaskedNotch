// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MaskedNotchCore",
    platforms: [.macOS("26.0")],
    products: [.library(name: "MaskedNotchCore", targets: ["MaskedNotchCore"])],
    targets: [
        .target(name: "MaskedNotchCore"),
        .testTarget(name: "MaskedNotchCoreTests", dependencies: ["MaskedNotchCore"], path: "Tests/MaskedNotchCoreTests")
    ],
    swiftLanguageModes: [.v5]
)
