// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SeldonChat",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .executable(name: "SeldonChat", targets: ["SeldonChat"])
    ],
    dependencies: [
        .package(url: "https://github.com/gonzalezreal/swift-markdown-ui", from: "2.4.1")
    ],
    targets: [
        .executableTarget(
            name: "SeldonChat",
            dependencies: [
                .product(name: "MarkdownUI", package: "swift-markdown-ui")
            ],
            path: "Sources/SeldonChat"
        )
    ]
)
