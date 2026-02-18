// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "seldon",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .executable(name: "seldon", targets: ["seldon"])
    ],
    dependencies: [
        .package(url: "https://github.com/gonzalezreal/swift-markdown-ui", from: "2.4.1")
    ],
    targets: [
        .executableTarget(
            name: "seldon",
            dependencies: [
                .product(name: "MarkdownUI", package: "swift-markdown-ui")
            ],
            path: "Sources/seldon"
        )
    ]
)
