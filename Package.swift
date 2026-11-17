// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SimpleTranslator",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "SimpleTranslator", targets: ["SimpleTranslator"])],
    targets: [
        .executableTarget(name: "SimpleTranslator"),
        .testTarget(name: "SimpleTranslatorTests", dependencies: ["SimpleTranslator"])
    ],
    swiftLanguageModes: [.v5]
)
